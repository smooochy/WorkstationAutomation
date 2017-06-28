Function Install-Application{
    [CmdletBinding()]
    param($ComputerName, $AppName)

    #Quit if computer doesn't ping or have application deployed
    If(!(Test-Connection -ComputerName $ComputerName -Count 1 -TTL 50 -ErrorAction SilentlyContinue)){
        Write-Error("Computer does not ping")
        Return
    }
    If(!($wmi = Get-WmiObject -ComputerName $ComputerName -Namespace root\ccm\clientsdk -Class CCM_Application | Where-Object{$_.Name -eq "$AppName"})){
        Write-Error("No such Application on computer")
        Return
    }

    #Display Application status for the computer
    $wmi | Format-Table PSComputerName, InstallState, Revision, @{Name='LastEvalTime';Expression={$_.ConvertToDateTime($_.LastEvalTime)}}, @{Name='LastInstallTime';Expression={$_.ConvertToDateTime($_.LastInstallTime)}}, ErrorCode -AutoSize

    Try{([wmiclass]"\\$ComputerName\ROOT\ccm\clientsdk:CCM_Application").Install($wmi.Id, $wmi.Revision, $wmi.IsMachineTarget, 0, 'Normal', $True) | Out-Null}
    Catch{$_.ToString()}

}