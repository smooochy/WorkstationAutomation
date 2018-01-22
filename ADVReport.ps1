param($inFile = $(throw 'Must provide input file'))#, $outFile = $(throw 'Must provide output file')
$objExcel = New-Object -comobject Excel.Application
$objExcel.visible = $True
$Workbooks = $objExcel.Workbooks.add()
$iteration = 1
$UninstallRegKey="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
$UninstallRegKey64="SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"

Function Get-UninstallKey {param($RegPath = $(throw 'Function Get-UninstallKey needs a RegPath'), $Column = $(throw 'Function Get-UninstallKey needs a Column'))
        $HKLM = [microsoft.win32.registrykey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,"$_") 
        $UninstallRef  = $HKLM.OpenSubKey($RegPath)
        $Applications = $UninstallRef.GetSubKeyNames()          
        Foreach ($App in $Applications) {
            $AppRegistryKey  = $RegPath + "\\" + $App            
            $AppDetails = $HKLM.OpenSubKey($AppRegistryKey)
            $AppNum += 1
            $AppDisplayName = $($AppDetails.GetValue("DisplayName"))
            $Appversion = $($AppDetails.GetValue("DisplayVersion"))
            If ($AppDisplayName -and !"$AppDisplayName".Contains("Security Update")) { 
                $Worksheet.Cells.Item($AppNum+5,$Column) = "$AppDisplayName $AppVersion"
            }
            Else{
                If (!$Applications[$appnum].Contains("{") -and (!$Applications[$appnum].Contains("KB"))) {
                    $Worksheet.Cells.Item($Appnum+5,$Column) = $Applications[$appnum]
                }
                Else{
                    $update += 1
                    $appnum -= 1
#Unnecessary        $Worksheet.Cells.Item($update+5,5) = $Applications[$appnum]
                }
            }
        }
}

#Begin Main
Get-Content $infile | Foreach-Object{

    Write-Host "Processing $_"
    $arrApps = @()
    $adv = 0
    $appnum = 0
    $pingBack = Test-Connection -computer $_ -Count 1 -TTL 100 -quiet #This returns a boolean
    [Void]$Workbooks.Worksheets.add([System.Reflection.Missing]::Value,$Workbooks.Worksheets.Item($Workbooks.Worksheets.count))
    $Worksheet = $Workbooks.Sheets.Item($iteration)
    $Worksheet.activate()
    $iteration += 1
    $Worksheet.Name = $_
    $Worksheet.Cells.Item(1,1) = "NETBIOS Name:"
    $Worksheet.Cells.Item(1,2) = "$_"
    $Worksheet.Cells.Item(2,1) = "Operating System:"
    $Worksheet.Cells.Item(3,1) = "Published Advertisements:"
    $Worksheet.Cells.Item(5,1) = "PKG_Name"
    $Worksheet.Cells.Item(5,2) = "ADV_ID"
    $Worksheet.Cells.Item(5,3) = "UninstallKey"
    $Worksheet.Cells.Item(5,4) = "UninstallKey64"
#   $Worksheet.Cells.Item(5,5) = "Security Updates"
    $Worksheet.Columns.Item(1).columnWidth = 25
    $Worksheet.Columns.Item(3).columnWidth = 60
    $Worksheet.Columns.Item(4).columnWidth = 60
    If($pingBack -eq $True){
        #Get info from WMI

        $OS = (Get-wmiobject -namespace root\CIMV2 -Class Win32_OperatingSystem -computername $_).Caption
        $ADVnum = (Get-wmiobject -namespace root\ccm\Policy\Machine -Class CCM_SoftwareDistribution -computername $_ -filter "ADV_ADF_Published = 'True'").Count
        $Worksheet.Cells.Item(2,2) = $OS
        $Worksheet.Cells.Item(3,2) = $ADVNum
        Get-wmiobject -namespace root\ccm\Policy\Machine -Class CCM_SoftwareDistribution -computername $_ -filter "ADV_ADF_Published = 'True'"| sort "PKG_Name" | Foreach-Object{
            $adv += 1
            #Add lines here to add info about each advertisement
            $Worksheet.Cells.Item($adv+5,1) = $_.PKG_Name
            $Worksheet.Cells.Item($adv+5,2) = $_.ADV_AdvertisementID
        }
        Get-UninstallKey -RegPath "$UninstallRegKey" -Column 3
        Get-UninstallKey -RegPath "$UninstallRegKey64" -Column 4
    }
}
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($objExcel)