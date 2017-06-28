Function Start-TaskSequence{
    [CmdletBinding()]
    param(
        $ComputerName = $(Write-Error 'Must provide node name'), `
        [String]$AdvertisementID = $(Write-Error 'Must provide Advertisement ID'), `
        [Switch]$OverrideServiceWindow = $True
    )
Process{    
    Function SetRerunBehavior($RerunBehavior, $LogonRequirement, $MandatoryAssignments, $NodeAdv){
        Foreach ($PKG in $NodeAdv){
            Write-Host "Setting rerun behavior for" $PKG.PKG_Name
            $OldRerunBehavior = $_.ADV_RepeatRunBehavior
            $OldLoggedOn = $_.PRG_PRF_UserLogonRequirement
            $OldMandatoryAssignments = $_.ADV_MandatoryAssignments
            $PKG.ADV_RepeatRunBehavior = $RerunBehavior
            $PKG.PRG_PRF_UserLogonRequirement = $LogonRequirement
            $PKG.ADV_MandatoryAssignments = $MandatoryAssignments
            $PKG.Put() | Out-Null
        }
    }

    Function OverrideServiceWindow{
        Foreach ($PKG in $NodeAdv){
            Write-Output "Overriding Service Window"
            #If($Action = 'Disable'){$PKG.PRG_Requirements.Replace($TrueOverride, $FalseOverride)}
            $XmlDoc = [xml]$PKG.PRG_Requirements
            $XmlNode = $XmlDoc.SelectSingleNode("SWDReserved/OverrideServiceWindows")
            $XmlNode.InnerText = "TRUE"
            $PKG.PRG_Requirements = $XmlDoc.InnerXml
            $PKG.Put()
        }
    }
    
    $TrueOverride = '<OverrideServiceWindows>True</OverrideServiceWindows>'
    $FalseOverride = '<OverrideServiceWindows>False</OverrideServiceWindows>'
    If (!(Test-Connection -computer $ComputerName -Count 1 -quiet)){Write-Error "$ComputerName does not ping back";Return}
    
    
    #Get PackageID from advertisement
    #$Advertisement = Get-WmiObject -ComputerName winsccmpss01 -Namespace root\SMS\Site_SH2 -Query "SELECT PackageID from SMS_Advertisement WHERE AdvertisementID = `'$AdvertisementID`'"
    #If (!($Advertisement)){Write-Error "$AdvertisementID does not exist on site server";Return}
    #$PackageID = $Advertisement.PackageID
    
    
    #Clear Status
    $key = 'SOFTWARE\Wow6432Node\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\'
    Try{
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)
        $soft = $reg.OpenSubKey($key, $true)
        $soft.DeleteSubKeyTree($PackageID)
    }
    Catch{Write-Output "No previous execution history for $AdvertisementID"}
    
    
    #Get Schedule ID
    If(($AdvSchMsgID = (Get-WmiObject -ComputerName $ComputerName -Namespace ROOT\ccm\scheduler -Class CCM_Scheduler_History -Filter "ScheduleID like `"$AdvertisementID%`"" -ErrorAction SilentlyContinue)) -eq $null){#If Trigger Schedule not found then exit.
        Write-Error "Schedule not found. $ComputerName never received $Advertisement"
        Return
    }
    $AdvSchMsgID = $AdvSchMsgID.ScheduleID
    
    
    #Set Rerun Behavior (no need for error checking unless want to catch weird WMI error; adv will exist here if scheduled message exist)
    $NodeAdv = Get-WmiObject -ComputerName $ComputerName -Namespace ROOT\ccm\Policy\Machine\ActualConfig -Query "SELECT * FROM CCM_SoftwareDistribution WHERE ADV_AdvertisementID = `'$AdvertisementID`'"
    SetRerunBehavior -RerunBehavior "RerunAlways" -LogonRequirement "None" -MandatoryAssignments "True" -NodeAdv $NodeAdv
    #Trigger Schedule (do it, son!)
    Write-Output "Rerunning $AdvertisementID on $ComputerName"
    If($OverrideServiceWindow){OverrideServiceWindow}
    Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule -ArgumentList "$AdvSchMsgID"
    }
}