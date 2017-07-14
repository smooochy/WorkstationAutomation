param(
    [Switch]$ApplicationOnly, 
    $FilePath = $(Read-Host "Enter Path to Config File:"),
    [Switch]$TSDeploy #Don't remember why I created this one but it's not used anywhere
)

Function Create-InstallCollection{
    param($Suffix, $DeployPurpose, $DeployAction)

    $CollectionName = "Deploy_$(NameFormat $Vendor $Name $Version)_$($Type)_$($Suffix)"

    If(!($Collection = Get-CMCollection -Name $CollectionName -ErrorAction SilentlyContinue)){
        If($DeployPurpose -eq 'Required'){$CMSchedule = $(New-CMSchedule -RecurCount 1 -RecurInterval Hours -Start $([DateTime]::MinValue).AddYears(2013).AddHours(1))}
        Else{$CMSchedule = $(New-CMSchedule -RecurCount 1 -RecurInterval Days -Start $([DateTime]::MinValue).AddYears(2013).AddHours(1))}
        Write-Host "Creating Install Collection: $CollectionName"
        $Collection = New-CMCollection -Name $CollectionName -LimitingCollectionId 'SH100660' -CollectionType Device -RefreshType Periodic -RefreshSchedule $CMSchedule
        If($CollectionName -like "Deploy_Oracle_JRE*"){
            Write-Host 'Creating Java Exclusion Rule'
            Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $CollectionName -ExcludeCollectionName 'SG_Exclusion_Oracle_Java' -Verbose
        }
    }
    Else{Write-Host "Collection $CollectionName already exists"}

    Write-Host "Starting deployment of $ApplicationName to $CollectionName"
    If(!(Get-CMDeployment -CollectionName $CollectionName -FeatureType Application -SoftwareName $ApplicationName)){
    Start-CMApplicationDeployment `
        -CollectionName $CollectionName `
        -DeployAction $DeployAction `
        -DeployPurpose $DeployPurpose `
        -Name "$ApplicationName" `
        -AvailableDateTime (Get-Date) `
        -TimeBaseOn LocalTime `
        -UserNotification DisplaySoftwareCenterOnly `
        -EnableMomAlert $False
    Return $Collection
    }
}

Function Create-ScopeCollection{
    param(
        [ValidateSet('Test','Prod','Installed')]
        $Classification,
        $Query
    )
    If($Classification -eq 'Test'){$CollectionName = "SG_$($Classification)_$($Type)_$(NameFormat $Vendor $Name)"} #Test collections/groups are non version specific
    Else{$CollectionName = "SG_$($Classification)_$($Type)_$(NameFormat $Vendor $Name $Version)"}
    If(!($Collection = Get-CMCollection -Name $CollectionName -ErrorAction SilentlyContinue)){
        $Collection = New-CMCollection -Name $CollectionName -LimitingCollectionId 'SH10000B' -CollectionType Device -RefreshType Continuous
        Move-CMObject -InputObject $Collection -FolderPath ".\DeviceCollection\Workstations\Scopes"
        Write-Host "$($Collection.Name) created. Creating membership rule."
        Add-CMDeviceCollectionQueryMembershipRule -Collection $Collection -RuleName "$(NameFormat $Vendor $Name $Version)_$Classification" -QueryExpression $Query
    }
    Else{Write-Host "$CollectionName already exists."}
}

Function NameFormat{
    param($Vendor, $Name, $Version)
    
    # Remove spaces and concatenate variables
    $FullName = (([string]$Vendor + " " + [string]$Name + " " + [string]$Version).Trim()) -replace (" ", "_")
    
    # Remove other retardedness
    Write-Output $FullName
    
}

###Main
#$filepath = Read-Host("Enter Filepath")
#$FileDir = $FilePath.Substring(0, $FilePath.LastIndexOf('\'))

$SiteCode = 'SH1'

$xml = $filepath

If(!(Test-Path $xml -PathType Leaf)){
    Write-Output "Invalid input. Please provide a valid config file"
    Write-Output "Syntax: Add-Package.ps1 <Path_To_Config_File>"
}

$ConfigPath = [String](Resolve-Path($xml))

If($ConfigPath.ToUpper().StartsWith("MICROSOFT.POWERSHELL.CORE\FILESYSTEM::\\")){
        $ConfigPath = (Copy-Item $ConfigPath $env:temp -Force -PassThru).FullName
}

$Config = Select-Xml -LiteralPath $ConfigPath -XPath "//Application" | Select-Object -ExpandProperty Node

#Set General variables and cd to the site server's PSDrive
$General = Select-Xml -Xml $Config -XPath "//Application/General" | Select-Object -ExpandProperty Node
$Vendor = $General.Vendor
$Name = $General.Title
$Version = $General.Version
$Type = $General.Type
#$Category = $General.Category

$ApplicationName = "$Vendor $Name $Version"
<<<<<<< HEAD
#$DisplayName = ($ApplicationName.Split('.') | Select -First 3)
Push-Location "$($SiteCode):\"
=======
$DisplayName = $ApplicationName.Split('.') | Select -First 3
Push-Location "$SiteCode:\"
>>>>>>> 0ce2054cca1fce2e74928389ba88b369946a3478

#Create Application
If(!($CMApplication = Get-CMApplication -Name "$ApplicationName" -ErrorAction SilentlyContinue)){
    Write-Host "Creating Application $ApplicationName"
    $CMApplication = New-CMApplication `
        -Name $ApplicationName `
        -SoftwareVersion $Version `
        -Publisher $Vendor `
        -AutoInstall:$True

    Set-CMApplication `
        -InputObject $CMApplication `
        #-LocalizedApplicationName $DisplayName `
        -AppCategories "Workstation $Type" `
        -Publisher $General.Vendor `
        -SoftwareVersion $General.Version `
        -Verbose
    
    Move-CMObject -FolderPath .\Application\Workstation -InputObject $CMApplication
    Write-Host "Adding $Type Administrative Category to Application"

}
Else{Read-Host "An application with name $ApplicationName already exists. Continue?"}


$DeploymentTypes = Select-Xml -Xml $Config -XPath "//Application/DeploymentTypes" | `
    Select-Object -ExpandProperty Node | `
    Select-Object -ExpandProperty DeploymentType

<#
Needs to be changed because Set-CMDeploymentType has been deprecated and will eventually be removed altogether.
Maybe create separate functions for MSI and script deployment types?
#>
Foreach($DeploymentType in $DeploymentTypes){
    If(($DeploymentType.Name -eq $null) -or ($DeploymentType.Name -eq '')){$DeploymentType.Name = $ApplicationName}
    If(Get-CMDeploymentType -InputObject $CMApplication -DeploymentTypeName $DeploymentType.Name -ErrorAction SilentlyContinue){break}
    Write-Host "Creating DeploymentType for $($DeploymentType.Name)"
    If($DeploymentType.Detection -like "*.msi"){#MSI Deployment Type
        Add-CMMsiDeploymentType `
            -Application $CMApplication `
            -DeploymentTypeName $($DeploymentType.Name) `
            -InstallationFileLocation "$($DeploymentType.Detection)" `
            -ForceForUnknownPublisher `
            -InstallationProgram $($DeploymentType.Install)
    }

    #If Product Code or anything non-msi, must change detection method manually in the console.
    Else{
        $ScriptContent = 'Return 0'
        Write-Warning "Remember to manually change Detection Method!"

        Add-CMScriptDeploymentType `
            -Application $CMApplication `
            -DeploymentTypeName $($DeploymentType.Name) `
            -InstallationProgram $($DeploymentType.Install) `
            -ScriptType PowerShell `
            -ScriptContent $ScriptContent
    }
    Set-CMDeploymentType `
        -MsiOrScriptInstaller `
        -ApplicationName $ApplicationName `
        -DeploymentTypeName $($DeploymentType.Name) `
        -LogonRequirementType WhetherOrNotUserLoggedOn `
        -RebootBehavior BasedOnExitCode `
        -InstallationProgramVisibility Hidden `
        -MaximumAllowedRunTimeMinutes 90 `
        -ContentLocation $($DeploymentType.Source) `
        -InstallationBehaviorType InstallForSystem `
        -RequiresUserInteraction $False `
        -OnSlowNetworkMode Download
}

Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName "All Distribution Points"

If(($ApplicationOnly) -or ($Type -eq 'Redistributable')){Pop-Location;Return "Will not create collections or metering rules."}

#Create Install Collections and Deployments
$Collection = Create-InstallCollection -Suffix 'Required' -DeployPurpose 'Required' -DeployAction 'Install'
Move-CMObject -InputObject $Collection -FolderPath ".\DeviceCollection\Workstations\Deployments"
If(($Type -eq 'Managed') -or ($Type -eq 'Restricted')){
    #$Collection = Create-InstallCollection -Suffix 'Uninstall' -DeployPurpose 'Required' -DeployAction 'Uninstall'
    If($Collection){Move-CMObject -InputObject $Collection -FolderPath ".\DeviceCollection\Workstations\Deployments"}
}
ElseIf($Type -eq 'Optional'){
    $Collection = Create-InstallCollection -Suffix 'Available' -DeployPurpose 'Available' -DeployAction 'Install'
    If($Collection){Move-CMObject -InputObject $Collection -FolderPath ".\DeviceCollection\Workstations\Deployments"}
}


#Create Scope Collections and AD Groups. Skip the installed scope collection if no/null/invalid product code provided
$Prod_Query = ("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System WHERE SystemGroupName = 'SHSU\\" + ("SW_" + $("$(NameFormat $Vendor $Name $Version)") + "_Stable") + "' AND Active = 1 AND Client = 1 AND ClientType = 1")
$Test_Query = ("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System WHERE SystemGroupName = 'SHSU\\" + ("SW_" + $("$(NameFormat $Vendor $Name $null)") + "_Test") + "' AND Active = 1 AND Client = 1 AND ClientType = 1")
Create-ScopeCollection -Classification Test -Query $Test_Query
If(!(Get-ADGroup -Filter "Name -eq `"SW_$(NameFormat $Vendor $Name $null)_Test`"")){New-ADGroup -Name "SW_$(NameFormat $Vendor $Name $null)_Test" -SamAccountName "SW_$(NameFormat $Vendor $Name $null)_Test" -Path "OU=$Type,OU=Test,OU=Software,OU=Domain Groups,DC=SHSU,DC=EDU" -GroupScope DomainLocal}

If(($Type -eq 'Managed') -or ($Type -eq 'Optional') -or ($Type -eq 'Restricted')){
    Create-ScopeCollection -Classification Prod -Query $Prod_Query
    If(!(Get-ADGroup -Filter "Name -eq `"SW_$(NameFormat $Vendor $Name $Version)_Stable`"")){New-ADGroup -Name "SW_$(NameFormat $Vendor $Name $Version)_Stable" -SamAccountName "SW_$(NameFormat $Vendor $Name $Version)_Stable" -Path "OU=$Type,OU=Stable,OU=Software,OU=Domain Groups,DC=SHSU,DC=EDU" -GroupScope DomainLocal -PassThru}
}


#Create Software Metering Rules
$Files = $config.SelectNodes("/Application/Metering/File")
If($Files){
    Foreach($FileName in $Files.'#text'){
        If(!(Get-CMSoftwareMeteringRule -ProductName "$(NameFormat $Vendor $Name $Version)_$($FileName)_(*)")){
            New-CMSoftwareMeteringRule `
                -ProductName "$(NameFormat $Vendor $Name $Version)_$($FileName)_(*)" `
                -FileName $FileName `
                -SiteCode $SiteCode `
                -LanguageId 65535 #This is the value for "Any" language
        }
    }
}

Pop-Location