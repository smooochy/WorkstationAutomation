#Get Script Directory and CD to it
$ScriptItem = Get-Item $($MyInvocation.MyCommand.Path)
$ScriptPath = $ScriptItem.DirectoryName
Push-Location $ScriptPath

#Get .jpg Images in Script Directory and Set RegKey Path
$Files = Get-ChildItem $ScriptPath -Filter "*.jpg"
$FileCount = $Files.Count - 1
$RegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'

#Create RegKey if Not Exist and Set "NoChangingLockScreen" Value
If(!(Test-Path $RegKey)){New-Item -Path $RegKey}
If(!((Get-ItemProperty -Path $RegKey -Name 'NoChangingLockScreen') -eq 1)){Set-ItemProperty -Path $RegKey -Name 'NoChangingLockScreen' -Value 1 -Force}

#Get Random Image and Set as LockScreen
Set-ItemProperty `
    -Path $RegKey `
    -Name 'LockScreenImage' `
    -Value $(($Files).FullName[$(Get-Random -Maximum $FileCount)]) `
    -Force