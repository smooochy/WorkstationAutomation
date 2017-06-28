$grouplist = ""
$groups = (Get-ADGroup -Filter * -SearchBase "OU=Software,OU=Domain Groups,DC=SHSU,DC=EDU").Name
$groups | ForEach-Object {$grouplist += "'$_',"}
$grouplist = $grouplist.TrimEnd(',')
$scriptblock = 
"Function global:Get-SoftwareGroupMember{
    [CmdLetBinding()]
    param([ValidateSet($grouplist)]`$Group)
    Get-ADGroupMember `$Group
}"
Invoke-Expression $scriptblock