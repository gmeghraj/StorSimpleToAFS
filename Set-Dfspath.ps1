<#[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string]$DFSMappingList_csv,
    [Parameter(ParametersetName='Set1')]
    [switch]$AddOriginalFSPath,
    [Parameter(ParametersetName='Set2')]
    [switch]$AddNewFSpath,
    [Parameter(ParametersetName='Set2')]
    [Switch]$removeOriginalFSpath
)
#>

$ConfirmPreference = 'Low'
filter timestamp {"$(Get-Date -f "dd-MMM-yyyy:hh:mm:ss"):$_"}
# Loading genral scripts.
Push-Location "E:\OtherScripts\LogonScriptUpdate"
#. .\Load-LoggingFunctions.ps1
$datestr = (Get-Date -f "dd_MM_yyyy_hh_mm_ss")
$cmdlet = ($PSCommandPath = Split-Path $PSCommandPath -Leaf).TrimEnd('.ps1')
$Logpath = "$PSScriptRoot\Logs\$($cmdlet)_$($datestr).log"
$outputPath = ".\Output\DFS-Mapping_$((get-Date -f 'dd_MM_yyyy_hh_mm_ss')).xlsx"



Start-Transcript -Path $Logpath -Confirm:$false
Write-Host "Type the path of input file." -ForegroundColor Yellow
$DFSMappingList_csv = Read-Host

Write-Host "Put the change number" -ForegroundColor Yellow
$changenumber = Read-Host

Write-Output "Input File path is $DFSMappingList_csv"|timestamp
$DFSMappingList_csv = $DFSMappingList_csv -replace """"
$DFSMappingList = $null 
$DFSMappingList = import-csv $DFSMappingList_csv -Encoding Default

IF (-not ($DFSMappingList.DFSPath.Length -gt 0)){return Write-Host "Exiting as the Input list is not valid" -ForegroundColor Cyan }

$i = 0
DO {
$i++
Write-Host "Press 'Y' to Add original FS path to DFS. Else press 'N' " -ForegroundColor Yellow
$AddOriginalFSPath = Read-Host

IF ($i -eq 3){
$i = 0
return "Exiting as you exceeded maximum attempts"
}
}
While ($AddOriginalFSPath -notmatch '(Y|N|y|n)')


$ConfirmPreference = 'low'
IF($AddOriginalFSPath -eq 'Y'){
    Write-output "Adding Original FS path to DFS"|timestamp
    $OriginalFSpathStatus = @()
    foreach ($l in $DFSMappingList){
        Write-Output "Setting up DFS to original FS path -  DFSPath:$($l.DFSpath)|TargetPath:$($l.OriginalFSPath)"|timestamp
        New-DfsnFolderTarget -Path $l.DFSPath -TargetPath $l.OriginalFSPath -Confirm:$false 
        Set-DfsnFolder -Path $l.DFSPath -Description $changenumber -Confirm:$false
        $desc = $null
        $desc = Get-DfsnFolder -Path $l.DFSPath
        $status = $null
        $status = Get-DfsnFolderTarget -Path $l.DFSPath |Select Path,TargetPath
        $Testpath = $null
        $Testpath = Test-Path $l.DFSPath

        $OriginalFSpathStatus += $L.DFSPath|Select @{n='Path';e={$l.DFSPath}},@{n='TargetPath';e={$status.TargetPath -join '|'}},@{n='TargetPathUpdated';e={$l.OriginalFSPath -eq $Status.TargetPath}},@{n='PathAccessible';e={$Testpath}},@{n='Description';e={$desc.Description}}
    }    
    Write-Output "Verifying if the DFS path is updated successfully"|timestamp
    IF ($OriginalFSpathStatus){
        $OriginalFSpathStatus|Export-Excel $outputPath -WorksheetName 'OriginalFSPath'
    }else {
        Write-Output "Map OriginalFSPath output is blank" |timestamp
    }
    IF ($OriginalFSpathStatus.TargetPathUpdated -contains $false -or $OriginalFSpathStatus.PathAccessible -contains $false){
        Write-Output "Some of the DFS paths encountered error. Please check logs"|timestamp
        $OriginalFSpathStatus|?{$_.TargetPathUpdated -eq $false -or $_.PathAccessible -eq $false}|ft

    }else {
            Write-Output "All DFS paths set successfully. check logs for more info."|timestamp
    }

}

$i = 0
DO {
$i++
Write-Host "Press 'Y' to Add New FS path to DFS. Else press 'N' " -ForegroundColor Yellow
$AddNewFSpath = Read-Host
    IF ($i -eq 3){
    $i = 0
    return "Exiting as you exceeded maximum attempts"
    }
}
While ($AddNewFSpath -notmatch '(Y|N|y|n)')

IF ($AddNewFSpath -eq 'Y'){
    $NewPathStatus = @()
    Write-Output "Adding New FS path to DFS"|timestamp
    foreach ($l in $DFSMappingList){
        Write-Output "Setting up DFP to New FS path -  DFSPath:$($l.DFSpath)|TargetPath:$($l.NewFSpath)"|timestamp
        New-DfsnFolderTarget -Path $l.DFSPath -TargetPath $l.NewFSpath -Confirm:$false
        $status = $null
        $status = Get-DfsnFolderTarget -Path $l.DFSPath|Select Path,TargetPath,@{n='TargetPathUpdated';e={$l.NewFSpath -in $_.TargetPath}}
        $Testpath = $null
        $Testpath = Test-Path $l.DFSPath
        $desc = $null
        $desc = Get-DfsnFolder -Path $l.DFSPath
        IF ($status.TargetPath -contains $l.NewFSpath){
         $NewPathStatus += $l.DFSPath|Select @{n='Path';e={$l.DFSPath}},@{n='TargetPath';e={($status.TargetPath -join '|')}},@{n='TargetPathUpdated';e={$true}},@{n='PathAccessible';e={$Testpath}},@{n='Description';e={$desc.Description}}
        }else{
          $NewPathStatus += $l.DFSPath|Select @{n='Path';e={$l.DFSPath}},@{n='TargetPath';e={$status.TargetPath -join '|'}},@{n='TargetPathUpdated';e={$false}},@{n='PathAccessible';e={$Testpath}},@{n='Description';e={$desc.Description}}
        }
    }
    Write-Output "Verifying if the DFS path is updated successfully"|timestamp

    IF ($NewPathStatus){
        $NewPathStatus|Export-Excel $outputPath -WorksheetName 'NewFSPath'
    }else {
        Write-Output "MapNewFSPath output is blank"|timestamp
    }

    IF ($NewPathStatus.TargetPathUpdated -contains $false){
        Write-Output "Some of the DFS paths encountered error. Please check logs"|timestamp
        $NewPathStatus|?{$_.TargetPathUpdated -eq $false -or $_.PathAccessible -eq $false}|ft
    }else {
        Write-Output "All DFS paths set successfully. Please check logs"|timestamp
    }

}



$i = 0
DO {
$i++
Write-Host "Press 'Y' to remove Original FS path from DFS. Else press 'N' " -ForegroundColor Yellow
$removeOriginalFSpath = Read-Host

IF ($i -eq 3){
$i = 0
return "Exiting as you exceeded maximum attempts"
}
}
While ($removeOriginalFSpath -notmatch '(Y|N|y|n)')


IF($removeOriginalFSpath -eq 'Y'){
    $RemovePathStatus = @()
    Write-Output "Removing Original FS path to DFS"|timestamp

    foreach ($l in $DFSMappingList){
        Write-Output "Removing target folder from DFS  -  DFSPath:$($l.DFSpath)|TargetPath:$($l.OriginalFSPath)"|timestamp

        Remove-DfsnFolderTarget -Path $l.DFSPath -TargetPath $l.OriginalFSPath -Confirm:$false -Force

        $Testpath = $null
        $Testpath = Test-Path $l.DFSPath
        $status = $null
        $status = Get-DfsnFolderTarget -Path $l.DFSPath|Select Path,TargetPath

        $RemovePathStatus += $l.DFSPath|Select @{n='path';e={$l.DFSPath}},@{n='TargetPath';e={$status.TargetPath -join '|'}},@{n='TargetPathUpdated';e={$l.NewFSpath -in $Status.TargetPath}},@{n='OriginalFSPathRemoved';e={$l.NewFSpath -eq $Status.TargetPath}},@{n='PathAccessible';e={$Testpath}}
    }

    IF ($RemovePathStatus){
        $RemovePathStatus|Export-Excel $outputPath -WorksheetName 'RemoveOriginalFSPath'
    }else {
        Write-Output "RemoveOriginalPath output is blank"|timestamp
    }

    IF ($RemovePathStatus.TargetPathUpdated -contains $false -or $RemovePathStatus.PathAccessible -contains $false){
        Write-Host "Some of the DFS paths encountered error. Please check logs"|timestamp
        $RemovePathStatus|?{$_.TargetPathUpdated -eq $false -or $RemovePathStatus.PathAccessible -eq $false}|ft
    }else {
        Write-Output "All OriginalFSpath removed from DFS successfully. Please check logs"|timestamp
    }

}
Write-Output "Output File path : $outputPath"|timestamp

Write-Output "Script execution complete"|timestamp
Stop-Transcript