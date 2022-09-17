$ALL_UserFDRs = Get-ChildItem F:\Users 
filter timestamp {"$(get-date -f 'dd-MMM-yyyy:hh:mm:ss'):$_"}
$Users_FDR_Size = @()
$i = 0
foreach ($f in $RootFDR)
{

$i++
Write-Output "Processing $i/$($RootFDR.count)::$($f.Fullname)"|timestamp
$size = $null

$size = '{0:N3}' -f ((Get-ChildItem $f.FullName -Recurse |Measure-Object -property Length -Sum).Sum/1gb)

$Users_FDR_Size += $f| Select Name,Fullname,@{n='SizeinGB';e={$size}}

}