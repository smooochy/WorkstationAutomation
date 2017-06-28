#Function Get-LabNodes{
#    [CmdletBinding()]
#    param([String]$Lab)
#    If($Lab){$Lab = "OU=$($Lab),"}
#    Get-ADComputer -Filter * -SearchBase "$($Lab)OU=Labs,OU=Workstations,OU=Domain Computers,DC=SHSU,DC=EDU"
#}

$Lablist = ""
$Lab = (Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Labs,OU=Workstations,OU=Domain Computers,DC=SHSU,DC=EDU").Name
$Lab | Foreach-Object {$Lablist += "'$_',"}
$Lablist = $Lablist.TrimEnd(',')
$scriptblock = 
"Function global:Get-LabNodes{
    [CmdletBinding()]
    param([ValidateSet($Lablist)]`$Lab)
    If(`$Lab){`$SelectedLab = `"OU=`$(`$Lab),`"}
    Get-ADComputer -Filter * -SearchBase `"`$(`$SelectedLab)OU=Labs,OU=Workstations,OU=Domain Computers,DC=SHSU,DC=EDU`"
}"
Invoke-Expression $scriptblock