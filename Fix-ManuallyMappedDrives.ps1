[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param (
    $changeID='CHGXXXX',
    $serverAliases=@('ukfile02','pon274'),
    $domainSuffix='christies.com',
    $shareMappingCSV='.\Input\Mapping_CHGXXXX.csv'
)

class ScriptFile {
   [String] $UserName
   [string] $Path
   [bool] $HasServerReference
   [int] $CountChanges=0
   [string] $BackupPath=$null
   [bool]$Success=$false
   [bool]$driveManuallyMapped=$false
   [string]$Result
   ScriptFile($Path,$UserName) {
       $this.Path = $Path
       $This.UserName = $UserName
   }
}



class RegExReplacePattern {
    [string]$Pattern
    [string]$ReplacementText        
    RegExReplacePattern($Pattern,$ReplacementText) {
        $this.Pattern=$Pattern
        $this.ReplacementText=$ReplacementText
    }
}

class Mapping {
    [String]$UserName
    [string]$ScriptPath
    [string]$DriveLetter
    [string]$TargetShare
    Mapping($ScriptPath,$DriveLetter,$TargetShare) {
        $this.ScriptPath=$ScriptPath
        $this.DriveLetter=$DriveLetter
        $this.TargetShare=$TargetShare
    }
}

function Write-Log {
<#
.SYNOPSIS
This function is used to write output to a log file (and console if desired)
.DESCRIPTION
This function is used to write output to a log file (and console if desired)
.EXAMPLE
Write-Log "Some text I want to log" -LogFile "c:\temp\mylog.txt"
This will init the log variable so subsequent calls do NOT need to supply the log file parameter
.EXAMPLE
Write-Log "some text I want to log" -FileOnly
This will write to file only (not to console) assuming function has been called previous with the log file parameter
.EXAMPLE
Write-Log "some text I want to log"
This will write to file and console assuming function has been called previous with the log file parameter
.NOTES
#>

[cmdletbinding()]

param
(
    [parameter(position=0)]
    [string]$LogData,
    [string]$LogFile=$null,
    [string]$ForegroundColor="white",
    [switch]$FileOnly=$false
    
)

    $LogLine=(get-date).tostring("yyyy-MM-dd-HH:mm:ss") + "  " + $LogData        

    if (!$FileOnly) {
        Write-Host $LogLine -ForegroundColor $ForegroundColor        
    }

    #store the log file value if it is provided
    if ($LogFile) { $global:LogFile = $LogFile }

    #check we have a log file value
    if (!$global:LogFile) {
        #Write-Error "Missing LogFile value - unable to write to log."
    } else {
        Out-File -InputObject $LogLine -FilePath $global:LogFile -Append -WhatIf:$false -confirm:$False
    }

}

function Write-LogError {
    param (
        [string]$LogData
    )
    Write-Log -LogData "[ERROR] $LogData" -ForegroundColor 'Red'
}

function Write-LogVerbose {
    param (
        [string]$LogData
    )
    if ($VerbosePreference -notmatch 'silent') {
        Write-Log -LogData "[VERBOSE] $LogData" -ForegroundColor 'Yellow'
    }
}

function Write-LogDebug {
    param (
        [string]$LogData
    )
    if ($DebugPreference -notmatch 'silent') {
        Write-Log -LogData "[DEBUG] $LogData" -ForegroundColor 'Cyan'
    }
}

function Start-LoggingToFile {
    param (
        $ScriptName,
        $LogPrefix,
        $LogFolder
    )
    try {
        if (($null -eq $LogPrefix) -and ($null -ne $ScriptName)) {
            $LogPrefix=[System.IO.Path]::GetFileNameWithoutExtension($ScriptName)
        }

        if ($null -eq $LogPrefix) {
            $LogPrefix=$PID
        }
        
        $LogFolder=Resolve-Path -path $LogFolder

        $logFile=join-path -path $LogFolder -childpath ($LogPrefix + "_" + (get-date).ToString("yyyy-MM-dd-HHmmss") + ".log")
        Write-Log -LogFile $logFile -logData "Started logging to $LogFile"

    } catch {
        throw $_
    }
}

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path

Start-LoggingToFile -Scriptname $PSCmdlet.MyInvocation.MyCommand.Name -LogFolder '.\Logs'

$outputFile=".\Output\ScriptFileUpdate_$($serverAliases[0])_$($changeID)_$((get-date).ToString('yyyy-MM-dd-HHmmss')).xlsx"

$serverPattern="\\\\($($serverAliases -join '|'))"

#generate patterns from the share mapping date
write-logverbose "Preparing replacement patterns"
$shareMapping=import-csv -path $shareMappingCSV
write-logverbose "Loaded $($shareMapping.count) share mappings"
[RegExReplacePattern[]]$patterns=@()
foreach($share in $shareMapping) {
    #build the regex ... note we will allow for option use of the domain suffix and all aliases
    $pattern="([A-Za-z]:) +($serverPattern(\.$($domainSuffix.replace('.','\.')))*\\$($share.OriginalShare.replace('$','\$')))"
    $patterns+=[RegExReplacePattern]::New($pattern,$share.NewDFSPath)        
}

$PatternsForManuallyMapped = @() 

foreach($share in $shareMapping) {
    #build the regex ... note we will allow for option use of the domain suffix and all aliases
    $pattern = $null
    $pattern="($serverPattern(\.$($domainSuffix.replace('.','\.')))*\\$($share.OriginalShare.replace('$','\$')))"
    $patterns+=[RegExReplacePattern]::New($pattern,$share.NewDFSPath)        
}



$ManuallyMappedDriveList = Import-Excel "E:\JenkinsProjectFiles\M365\MWP\CollectDrives\Drives.xlsx"|?{$_.DriveDescription -like "RESOURCE REMEMBERED*"}|Select Username,DriveLetter,@{n='TargetShare';e={$_.DriveTarget}} -Unique
$matchesForManuallyMappedDrives = @()
$i=0
Foreach ($l in $ManuallyMappedDriveList){
$i++;$i
    foreach ($pattern in $patterns)
    {
    $matchFound = $null
    $matchFound = $l.TargetShare|Select-String -Pattern $pattern.Pattern
        IF ($null -ne $matchFound){
        Write-Host "Matched"
        $matchesForManuallyMappedDrives += $l|Select *,@{n='Matches';e={$True}},@{n='ReplacementPath';e={$pattern.ReplacementText}},@{n='Path';e={$filesToProcess.path -like "*\$($_.UserName)\*"}}
        }
        
    }
}
#add static patterns
#$patterns+=[RegExReplacePattern]::New('/persistent:yes','/persistent:no')        

write-log "Processing $($pattern.count) patterns for replacement -`n$($patterns | out-string)"

#create an array for files which we need to process
$filesToProcess=@()

#create an array for the list of mappings
$mappingsFound=@()

#$filesToProcess+=[ScriptFile]::New('\\christies.com\filesharing\peruserlogonscripts\mcook\settings.bat')



write-log "Fetching ENABLED users with HomeDirectories"
$users=Get-ADUser -resultsetsize 100000 -filter '(Enabled -eq $true) -and (HomeDirectory -like "*")' -Properties HomeDirectory
write-log "Found $($users.count) ENABLED users with a HomeDirectory"

#$users.HomeDirectory | % { $filesToProcess+=[ScriptFile]::New($_.TrimEnd('\')+'\settings.bat') }
$users[0..10]|% { $filesToProcess+=[ScriptFile]::New(($_.HomeDirectory.TrimEnd('\')+'\settings.bat'),$_.SamaccountName) }

$perUserDirs=$(get-childitem \\christies.com\filesharing\peruserlogonscripts -Directory)
write-log "Found $($perUserDirs.count) peruserlogonscripts folders"

$perUserDirs | % { $filesToProcess+=[ScriptFile]::New(($_.FullName+'\settings.bat'),$_.Name) }


write-log "Found $($filesToProcess.count) files for processing"

foreach($file in $filesToProcess) {
    try {    
        write-logverbose "Processing $($file.path)"
        $settingsBatFile=$null            
        $settingsBatFile=get-item -path $file.Path -force -erroraction stop
    
        write-logdebug "Found $($settingsBatFile.fullname)"     

        #do a quick check with select-string for the server
        $matchesForFile=select-string -pattern $serverPattern -path $settingsBatFile.fullname       
        if ($null -ne $matchesForFile) {
            write-logdebug "Found matches for server, proceeding to check for further patterns"
            $file.HasServerReference = $True
            $impactedMappedDrives=@()            
            $content=Get-content -path $settingsBatFile.FullName
            foreach($pattern in $patterns) {                
                write-logdebug "Replacing any occurences of $($pattern.pattern)"
                $changedContent=$content | % {
                    if ($_ -match $pattern.pattern) {
                        $impactedMappedDrives+=[Mapping]::New($File.userName,$settingsBatFile.FullName,$matches[1],$matches[2])
                        $changedContent=$content | % { $_ -replace $pattern.pattern,"`$1 $($pattern.ReplacementText)" }
                        $file.CountChanges++
                        write-logdebug "Matched the pattern and replaced content, drive letter is $($matches[1]), change count is now $($file.CountChanges)"                    
                        $content=$changedContent                                
                    }                
                }                
            }
            
            if ($file.CountChanges -gt 0) {
                write-logverbose "$($file.CountChanges) replacements were made"                

                $mappingsFound+=$impactedMappedDrives
                $changedContent=@()
                foreach($letter in $($impactedMappedDrives.DriveLetter | sort -unique)) {
                    write-logdebug "Adding net use delete for $letter"
                    $changedContent+="NET USE $letter /DELETE"
                }
                $content | % { $changedContent+=$_ }
                $content=$changedContent              

                $backupFileName=$settingsBatFile.Directory.FullName + "\settings_" + $changeID + "_" + (get-date).ToString('yyyy-MM-dd-HHmmss') + ".bat"
                $file.backupPath=$backupFileName
                if ($PSCmdlet.ShouldProcess($file.Path,"Create backup AND update file")) {                
                    write-logverbose "Creating backup file $backupFileName"
                    $backupFile=copy-item -path $settingsBatFile.FullName -destination $backupFileName -force -confirm:$false -PassThru
                    if ($null -ne $backupFile) {
                        $backupFile.Attributes+='Hidden'
                        write-logverbose "Writing content"
                        $settingsBatFile.Attributes=@()
                        $content | out-file -FilePath $settingsBatFile.Fullname -force -confirm:$false -encoding ASCII
                        $settingsBatFile.Attributes+='Hidden'
                        $file.Success=$true
                        $file.Result = "File updated"
                    } else {
                        write-error 'Failed to create backup - unable to proceed'
                        $file.Result = "ERROR - Failed to create backup"
                    }
                } else {
                    $file.Success=$true
                    $file.Result = "WHATIF - File would have been updated"
                }

            } else {
                write-logverbose "No replacements made."
                $file.Result = "No replacements made"
                $file.Success = $true
            }        

        } else {
            $file.HasServerReference = $False
            $file.Success = $True
            $file.Result = "No replacements made"
        }            

    } catch {
        write-logerror ($_.exception | out-string)
        $file.Result = $_.Exception.Message
    }

}

# Updated settings.bat of the users who manually mapped the drives.



write-log "Writing report to $outputFile"

$previousDebugPreference=$DebugPreference
$previousVerbosePrefernece=$VerbosePreference
$DebugPreference='SilentlyContinue'
$VerbosePreference='SilentlyContinue'
export-excel -path $outputFile -input $filesToProcess -worksheetname 'ScriptFiles'
export-excel -path $outputFile -input $mappingsFound -worksheetname 'Mappings'
$DebugPreference=$previousDebugPreference
$VerbosePreference=$previousVerbosePreference

write-log "Finished"

