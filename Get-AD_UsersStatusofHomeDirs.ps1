$userDir = Invoke-Command -ComputerName NYFILSRV05P -ScriptBlock {
        Get-ChildItem -Path "F:\user*"|Get-ChildItem -Directory}

$ADstatus = @()
$i = 0
Foreach ($u in $userDir){

    $user = "$(($u.name).trimend('$'))"

$ADStatusHash = [ordered]@{}
$ADStatusHash['HomeDirectoryName']=$u.Name
$ADStatusHash['Status']='NotFoundInAD'
$ADStatusHash['SamaccountName']=$user
$ADStatusHash['Enabled']=$null
$ADStatusHash['GivenName']=$null
$ADStatusHash['SurName']=$null
$ADStatusHash['HomeDirectory']=$null
$ADStatusHash['FSPath']=$u.Path
$ADStatusHash['DistinguishedName']=$null


$i++;$i
    
    try {

    $Obj = $null    
    $Obj = Get-ADUser "$user" -Properties HomeDirectory|Select SamaccountName,@{n='Status';e={'FoundInAD'}},Enabled,GivenName,Surname,UserPrincipalName,HomeDirectory,DistinguishedName
    $ADStatusHash['SamaccountName']=$obj.SamaccountName
    $ADStatusHash['Status']='FoundInAD'
    $ADStatusHash['Enabled']=$Obj.Enabled
    $ADStatusHash['GivenName']=$Obj.GivenName
    $ADStatusHash['SurName']=$Obj.Surname
    $ADStatusHash['HomeDirectory']=$Obj.HomeDirectory
    $ADStatusHash['DistinguishedName']=$Obj.DistinguishedName



    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    
    $Obj = $null
    $Obj = Get-ADUser "$($user)111" -Properties HomeDirectory|Select SamaccountName,@{n='Status';e={'FoundButInactive'}},Enabled,GivenName,Surname,UserPrincipalName,HomeDirectory,DistinguishedName
    
    $ADStatusHash['SamaccountName']=$obj.SamaccountName
    $ADStatusHash['Status']='FoundInAD'
    $ADStatusHash['Enabled']=$Obj.Enabled
    $ADStatusHash['GivenName']=$Obj.GivenName
    $ADStatusHash['SurName']=$Obj.Surname
    $ADStatusHash['HomeDirectory']=$Obj.HomeDirectory
    $ADStatusHash['DistinguishedName']=$Obj.DistinguishedName



    }
    Finally {
    
        $ADstatus += New-Object PSCUstomObject -Property $ADStatusHash

    
    }
}