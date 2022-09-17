[CmdletBinding()]
param (
$ServerName = $env:COMPUTERNAME,
[string[]]$DriveLetter,
[String]$ShareList_csv = $false,
[Parameter(ParameterSetName='Set2')]
[switch]$TopLevelACLOnly,
[Parameter(ParameterSetName='Set1')]
[Switch]$SharePermissionOnly
)
filter timestamp {"$(get-date -f 'dd-MM-yyyy:hh:mm:ss'):$_"}

$outputPath = ".\Output\SharePermissionList_$($ServerName)_$((get-Date -f 'dd_MM_yyyy_hh_mm_ss')).xlsx"
# Loading genral scripts.
. .\Load-LoggingFunctions.ps1

Start-LoggingToFile -Scriptname $PSCmdlet.MyInvocation.MyCommand.Name -LogFolder '.\Logs'
Write-Output "Setting the variable $ShareList as False to avoide 'Null variable error while running invoke-command"|timestamp
$sharelist = $false
IF ($ShareList_csv -ne $false){
    Write-Log "importing ShareListCSV file."
    $Sharelist = import-csv $ShareList_csv
    IF (-not($Sharelist.name.Length -gt 0)){return Write-Host "Exiting.. ShareList csv file is invalid" -ForegroundColor Cyan}
    }

#write-logverbose "Checing connection to the server"
IF (-not ((Test-Connection $ServerName).PingSucceeded)){
    throw "Failed to connect to the server:$servername."
    exit
}
write-log "Generating PSSession to the server:$servername"
try {
$ServerSession = $null
$ServerSession = New-PSSession -ComputerName $ServerName
write-log "PSSession generated successfully on the server:$servername"

}
catch {
    write-log "PSSession generation failed on the server:$servername"

    throw $_
}


Invoke-Command -Session $ServerSession -ScriptBlock {

filter timestamp {"$(get-date -f 'dd-MM-yyyy:hh:mm:ss'):$_"}
$DriveLetter = $using:DriveLetter
$DriveLetterRegex = "^($($DriveLetter -join '|')\\)"
$fqdn =  "$env:COMPUTERNAME\$env:USERDNSDOMAIN"
$accessMask = [ordered]@{
  [uint32]'0x80000000' = 'GenericRead'
  [uint32]'0x40000000' = 'GenericWrite'
  [uint32]'0x20000000' = 'GenericExecute'
  [uint32]'0x10000000' = 'GenericAll'
  [uint32]'0x02000000' = 'MaximumAllowed'
  [uint32]'0x01000000' = 'AccessSystemSecurity'
  [uint32]'0x00100000' = 'Synchronize'
  [uint32]'0x00080000' = 'WriteOwner'
  [uint32]'0x00040000' = 'WriteDAC'
  [uint32]'0x00020000' = 'ReadControl'
  [uint32]'0x00010000' = 'Delete'
  [uint32]'0x00000100' = 'WriteAttributes'
  [uint32]'0x00000080' = 'ReadAttributes'
  [uint32]'0x00000040' = 'DeleteChild'
  [uint32]'0x00000020' = 'Execute/Traverse'
  [uint32]'0x00000010' = 'WriteExtendedAttributes'
  [uint32]'0x00000008' = 'ReadExtendedAttributes'
  [uint32]'0x00000004' = 'AppendData/AddSubdirectory'
  [uint32]'0x00000002' = 'WriteData/AddFile'
  [uint32]'0x00000001' = 'ReadData/ListDirectory'
}

Write-Output "ShareList_csv:$using:ShareList_csv"|timestamp

If ($using:ShareList_csv -ne $false){

    Write-output "Defining ShareList variable inside PSSession"|timestamp
    $ShareList = $using:ShareList

    $smbshare = Get-SmbShare -Special:$false|?{$_.Name -in $Sharelist.Name}|Select @{n='ComputerName';e={$env:COMPUTERNAME}},Name,Path,@{n='SharePath';e={"\\$($env:COMPUTERNAME)\$($_.Name)"}},Description
}else {
    $smbshare = Get-SmbShare -Special:$false|?{$_.path -match $DriveLetterRegex}|Select @{n='ComputerName';e={$env:COMPUTERNAME}},Name,Path,@{n='SharePath';e={"\\$($env:COMPUTERNAME)\$($_.Name)"}},Description
}
$sharePermission = @()
$i = 0
Foreach ($s in $smbshare){
$i++
Write-Output "Getting Sharepermission $i/$($smbshare.count):: $($s.SharePath)"|timestamp
$sharePermission += Get-SmbShareAccess $s.Name|select *,@{n='SharePath';e={$p.SharePath}},@{n='path';e={$s.Path}},@{n='ComputerName';e={$env:COMPUTERNAME}}
}

Write-output "SharePermissionOnly - $Using:SharePermissionOnly"|timestamp

IF ($using:SharePermissionOnly -eq $true){write-output 'Exiting as only sharePermission is requested'|timestamp;break}
$TopLevelAcl =@()
$SubLevelAcl = @()

foreach ($s in $smbshare){
            $TopLevelAcl += get-acl -Path $s.path|select -ExpandProperty Access|select @{n='Sharename';e={$s.Name}},@{n='SharePath';e={$s.SharePath}},@{n='Path';e={$s.path}},IdentityReference,AccessControlType,Isinherited,`
            @{n='FilesystemRights';e={if ($_.FileSystemRights -match '\d'){$permission = $accessMask.Keys |? { $acl.FileSystemRights.value__ -band $_ } |% { $accessMask[$_] }
            $permission -join '|'}else {$_.FileSystemRights}}}
}
Write-output "TopLevelACL - $Using:TopLevelACLOnly"|timestamp
IF ($using:TopLevelACLOnly -eq $true){write-output 'Exiting as only TopLevelACL is requested'|timestamp;break}
 IF (-not $Using:TopLevelACLOnly -eq $true){
    
        Foreach ($s in $smbshare){
                $path = "\\?\$($s.Path)"
                $path
                $SubLevelAcl += Get-ChildItem $s.Path -Directory -Recurse| get-acl|select -ExpandProperty Access|?{$_.IsInherited -eq $false}|select @{n='Sharename';e={$s.Name}},@{n='SharePath';e={$s.SharePath}},@{n='Path';e={$s.path}},IdentityReference,AccessControlType,Isinherited,`
                @{n='FilesystemRights';e={if ($_.FileSystemRights -match '\d'){$permission = $accessMask.Keys |? { $acl.FileSystemRights.value__ -band $_ } |% { $accessMask[$_] }
                $permission -join '|'}else {$_.FileSystemRights}}}
        }
    }
}
Write-Log "Output file loction:$outputPath"
$smbshare = Invoke-Command -Session $ServerSession -ScriptBlock {$smbshare}
$sharePermission = Invoke-Command -Session $ServerSession -ScriptBlock {$sharePermission}
$TopLevelAcl = Invoke-Command -Session $ServerSession -ScriptBlock {$TopLevelAcl}
$SubLevelAcl = Invoke-Command -Session $ServerSession -ScriptBlock {$SubLevelAcl}
IF ($smbshare){$smbshare|Export-Excel $outputPath -WorksheetName 'smbsharelist'} else {Write-Log "smbshare data missing"}
IF ($sharePermission){$sharePermission |Export-Excel $outputPath -WorksheetName 'SharePermission'} else {Write-Log "SharePermission data missing"}
IF ($TopLevelAcl){$TopLevelAcl|Export-Excel $outputPath -WorksheetName 'TopLevelACL'} else {Write-Log "TopLevelACL data missing"}
IF ($SubLevelAcl){$SubLevelAcl|Export-Excel $outputPath -WorksheetName 'SubLevelAcl'} else {Write-Log "SubLevelACL data missing"}

