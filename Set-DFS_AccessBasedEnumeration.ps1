[CmdletBinding()]
param (
[Parameter(Mandatory=$true)]
$DFS_ABEList_csv
)
$ConfirmPreference = 'Low'
filter timestamp {"$(Get-Date -f "dd-MMM-yyyy:hh:mm:ss"):$_"}
# Loading genral scripts.
Push-Location "E:\OtherScripts\LogonScriptUpdate"
#. .\Load-LoggingFunctions.ps1
$datestr = (Get-Date -f "yyyy-MM-dd-hhmmss")
$cmdlet = ($PSCommandPath = Split-Path $PSCommandPath -Leaf).TrimEnd('.ps1')
$Logpath = "$PSScriptRoot\Logs\$($cmdlet)_$($datestr).log"
$outputPath = ".\Output\DFS-ABE_$((get-Date -f 'yyyy-MM-dd-hhmmss')).csv"
Start-Transcript -Path $Logpath -Confirm:$false
#Write-Host "Type the path of input file." -ForegroundColor Yellow
#$DFS_ABEList_csv = Read-Host

Write-Output "Input File path is $DFS_ABEList_csv"|timestamp
$DFS_ABEList_csv = $DFS_ABEList_csv -replace """"
$DFS_ABEList = $null 
$DFS_ABEList = import-csv $DFS_ABEList_csv -Encoding Default
$output = @()
IF (-not ($DFS_ABEList.DFSPath.Length -gt 0)){return Write-Output "Exiting as the Input list is not valid" -ForegroundColor Cyan }

Foreach ($path in $DFS_ABEList){
$i++
$dfscmd = $null
$dfscmd = @"
dfsutil property sd grant "$($path.DFSPath)" "$($path.Account)":RX protect
"@
Write-Output "processing $i/$($DFS_ABEList.count)::Dfspath:$($path.DFSPath)|Account:$($path.Account)"|timestamp
cmd /c  $dfscmd
$Status = $null
$Status = Get-DfsnAccess $Path.DFSPath

$output += $path |Select DfsPath,Account,@{n='Status';e={($Status.AccountName -contains $_.Account)}}

    IF ($Status.AccountName -notcontains $Path.Account){
        Write-Output "Failed to Add Account"|timestamp    
    }else {        Write-Output "Command executed successfully"|timestamp    
    }

}

IF ($output){$output|Export-Csv $outputPath -NoTypeInformation -Confirm:$false}
Write-Output "Output path:$outputPath"
Stop-Transcript




