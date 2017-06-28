$grouplist = ""
$groups = (Get-ADGroup -Filter * -SearchBase "OU=Software,OU=Domain Groups,DC=SHSU,DC=EDU").Name
$groups | % {$grouplist += "'$_',"}
$grouplist = $grouplist.TrimEnd(',')
$scriptblock = 
"Function global:Get-SoftwareGroup{
    [CmdLetBinding()]
    param([ValidateSet($grouplist)]`$Group)
    Get-ADGroup `$Group
}"
Invoke-Expression $scriptblock