[CmdletBinding()]
param (
[String]$ServerName ,
[Parameter(Mandatory=$true)]
[string]$sharepermissionList_CSV
)
filter timestamp {"$(Get-Date -f "dd-MMM-yyyy:hh:mm:ss"):$_"}

$datestr = (Get-Date -f "yyyy-MM-dd-hhmmss")
$outputPath = ".\Output\Set_SharePermissionList_$($ServerName)_$datestr.csv"
$cmdlet = ($PSCommandPath = Split-Path $PSCommandPath -Leaf).TrimEnd('.ps1')
$Logpath = "$PSScriptRoot\Logs\$($cmdlet)_$($datestr).log"
Start-Transcript -Path $Logpath -Confirm:$false


Write-Output "Checking connection to the server"|timestamp

IF (-not ((Test-Connection $ServerName).PingSucceeded)){
    throw "Failed to connect to the server:$servername."
    exit
}

Write-Output "importing data from input file"|timestamp
$sharepermissionList = import-csv $sharepermissionList_CSV    

Write-Output "Generating PSSession to the server:$servername"|timestamp
try {
$ServerSession = $null
$ServerSession = New-PSSession -ComputerName $ServerName
Write-Output "PSSession generated successfully on the server:$servername"|timestamp

}
catch {
    Write-Output "PSSession generation failed on the server:$servername"|timestamp

    throw $_
}
Invoke-Command -Session $ServerSession -ScriptBlock {
filter timestamp {"$(Get-Date -f "dd-MMM-yyyy:hh:mm:ss"):$_"}

$sharepermissionList = $using:sharepermissionList
$output = @()
$shareList = $sharepermissionList|select -Unique -Property Name,path

    $i = 0
    foreach ($s in $shareList){
    $i++

    Write-Output "$i/$($shareList.Count)::creating share:$($s.Name)|Path:$($s.Path)"|timestamp
    New-SmbShare -Name $s.Name -Path $s.path -FolderEnumerationMode AccessBased -Confirm:$false

    }
    $i = 0
    Foreach ($s in $sharepermissionList){
        $i++
        IF (Get-SmbShare $s.Name -ErrorAction SilentlyContinue){
        Write-Output "$i/$($sharepermissionList.Count)::Granting sharePermission to the share:$($s.Name)|AccountName:$($s.AccountName)"

        $commandArg = @{}
        $commandArg['Name']=$s.Name
        $commandArg['Account']=$s.Accountname
            IF(($s.AccessRight -eq 'Full') -or ($s.AccessRight -eq 0) ){
                $commandArg['AccessRight']=1
            }else {
                $commandArg['AccessRight']=$s.AccessRight
            }

        Grant-SmbShareAccess @commandArg -Confirm:$false|Out-Null
        $status = $null
        $status = Get-SmbShareAccess $s.Name |?{$_.AccountName -eq $s.AccountName -and $_.accessRight -eq $commandArg['AccessRight']}
            IF ($null -ne $status){
                Write-Output "$i/$($sharepermissionList.Count)::SharePermission granted successfully."
                $output += $s|Select Name,path,Accountname,@{n='AccessRight';e={$status.accessright}},@{n='Sharecreated';e={$true}},@{n='PermissionGranted';e={$true}}
            }else {
                Write-Output "$i/$($sharepermissionList.Count)::Failed to grant share permission."
                $output += $s|Select Name,path,Accountname,@{n='AccessRight';e={$commandArg['AccessRight']}},@{n='Sharecreated';e={$true}},@{n='PermissionGranted';e={$false}}
            }

        }else {
        Write-Output "$i/$($sharepermissionList.Count):: Could not find the share:$($s.Name)|path:$($s.path)"
        $output += $s|Select Name,path,Accountname,@{n='AccessRight';e={$status.accessright}},@{n='Sharecreated';e={$false}},@{n='PermissionGranted';e={$false}}
        }
    }
}

$output = invoke-command -Session $ServerSession -ScriptBlock{$output}
if ($output){$output|export-csv $outputPath -NoTypeInformation -Confirm:$false}else {Write-Output "Output not generated"|timestamp}
Write-Output "Output path:$outputPath"
Write-Output "Script execution completed"
Stop-Transcript
