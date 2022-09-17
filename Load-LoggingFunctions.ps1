
# These are general functions.
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
    