param (
    [string]$shareMappingCSV='.\Input\Mapping_CHG0053008.csv',
    [string]$changeID='CHG0053008',
    $serverAliases=@('ukfile01','pon263'),
    [string]$domainSuffix='christies.com'
)

class RegExReplacePattern {
    [string]$Pattern
    [string]$ReplacementText        
    RegExReplacePattern($Pattern,$ReplacementText) {
        $this.Pattern=$Pattern
        $this.ReplacementText=$ReplacementText
    }
}

class Mapping {
    [string]$ScriptPath
    [string]$DriveLetter
    [string]$TargetShare
    Mapping($ScriptPath,$DriveLetter,$TargetShare) {
        $this.ScriptPath=$ScriptPath
        $this.DriveLetter=$DriveLetter
        $this.TargetShare=$TargetShare
    }
}

class MatchedItem {
    [string] $Path
    [bool] $HasServerReference
    [int] $CountChanges=0
    [string] $BackupPath=$null
    [bool]$Success=$false
    [string]$Result
    ScriptFile($Path) {
        $this.Path = $Path
    }
 }
#loading general funtions.
.\Load-LoggingFunctions.ps1
$driveListPath = "E:\JenkinsProjectFiles\M365\MWP\CollectDrives\Drives.xlsx"
# importing the excel sheet generated by Matt cook's script that contains drives mapped to user's profiles.
IF (-not (test-path $DriveList )){
    throw "the Drives.xlsx file not found. contact Matt Cook"
    #exit
}else {
    $DriveList = import-excel $driveListPath |? {$_.DriveDescription -like "Resource Connected*"}|Select userName,DriveTarget -Unique
}


$serverPattern="\\\\($($serverAliases -join '|'))"
<#
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
#>

        #do a quick check with select-string for the server pattern
        foreach($item in $DriveList) {
            try {    
                write-logverbose "Processing UserName:$($Item.UserName)|DriveLetter:$($item.DriveLetter)|DriveTarget:$($Item.DriveTarget)"
     
                #do a quick check with select-string for the server
                $matchesforItem = $item.DriveTarget|select-string -pattern $serverPattern -path $settingsBatFile.fullname       
                if ($null -ne $matchesForItem) {
                    write-logdebug "Found matches for server, proceeding to check for further patterns"
                    $file.HasServerReference = $True
                    $impactedMappedDrives=@()            
                    $content=Get-content -path $settingsBatFile.FullName
                    foreach($pattern in $patterns) {                
                        write-logdebug "Replacing any occurences of $($pattern.pattern)"
                        $changedContent=$content | % {
                            if ($_ -match $pattern.pattern) {
                                $impactedMappedDrives+=[Mapping]::New($settingsBatFile.FullName,$matches[1],$matches[2])
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
        




