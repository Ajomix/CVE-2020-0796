# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

Param
(
    [int]$Step = 1,
    [string] $domain,
    [string] $userName,
    [string] $userPwd
)

#------------------------------------------------------------------------------------------
# Function: Write-ConfigLog
# Write information to log file
#------------------------------------------------------------------------------------------
Function Write-ConfigLog {
    Param (
        [Parameter(ValueFromPipeline = $true)] $text,
        $ForegroundColor = "Green"
    )

    $date = Get-Date -f MM-dd-yyyy_HH_mm_ss
    Write-Host "[$date] $text" -ForegroundColor $ForegroundColor
}

$isAutomation            = $false
$WorkingPath      	     = "C:\Temp"
$ScriptFileFullPath      = $MyInvocation.MyCommand.Definition
$ScriptName              = [System.IO.Path]::GetFileName($ScriptFileFullPath)
$LogFileFullPath         = "$ScriptFileFullPath.log"
$SignalFileFullPath      = "$WorkingPath\post.finished.signal"
$sutName                 = $env:computername
$sutIp                   = (Test-Connection $sutName -count 1 | select -ExpandProperty Ipv4Address).IPAddressToString

$configPath				 = "$WorkingPath\protocol.xml"

# Switch to the working path
if (Test-Path "$WorkingPath") {
    Write-ConfigLog "Switching to $WorkingPath..." -ForegroundColor Yellow
    Push-Location $WorkingPath
}

if (Test-Path "$configPath") {
    [xml]$Content = Get-Content $configPath
    $sutSetting = $Content.lab.servers.vm | Where-Object { $_.role -eq "SUT" }
    $coreSetting = $Content.lab.core
    if(![string]::IsNullOrEmpty($coreSetting.regressiontype) -and ($coreSetting.regressiontype -eq "Azure")){
        $SignalFileFullPath = "$env:SystemDrive\PostScript.Completed.signal"
    }
    $domain = $sutSetting.domain
    $userName = $coreSetting.username
    $userPwd = $coreSetting.password
    $sutName = $sutSetting.name
    $sutIp = $sutSetting.ip
    $isAutomation = $true
}

#------------------------------------------------------------------------------------------
# Function: Start-ConfigLog
# Create log file and start logging
#------------------------------------------------------------------------------------------
Function Start-ConfigLog() {
    if (!(Test-Path -Path $LogFileFullPath)) {
        New-Item -ItemType File -path $LogFileFullPath -Force
    }
    Start-Transcript $LogFileFullPath -Append 2>&1 | Out-Null
}

Function Complete-Configure {
    if($isAutomation)
    {
        # Write signal file
        Write-ConfigLog "Write signal file`: $SignalFileFullPath to hard drive."
        cmd /C ECHO CONFIG FINISHED > $SignalFileFullPath
    }    

    # Ending script
    Write-ConfigLog "Config finished."
    Write-ConfigLog "EXECUTE [$ScriptName] FINISHED (NOT VERIFIED)." -ForegroundColor Green
    Stop-Transcript


    # clean up the registry entry after calling RestartAndRun.ps1
    $private:regRunPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" 
    $private:regKeyName = "TKFRSAR"
    if (((Get-ItemProperty $regRunPath).$regKeyName) -ne $null)
    {
        Remove-ItemProperty -Path $regRunPath -Name $regKeyName
    }
    Restart-Computer
}

#------------------------------------------------------------------------------------------
# Function: Init-Environment
# Start logging, check signal file, switch to script path and read the config parameters
#------------------------------------------------------------------------------------------
Function Init-Environment() {
    # Start logging
    Start-ConfigLog

    # Start executing the script
    Write-ConfigLog "Executing [$ScriptName]..." -ForegroundColor Cyan
}

#------------------------------------------------------------------------------------------
# Function: Config-Environment
# Control the overall workflow of all configuration phases
#------------------------------------------------------------------------------------------
Function Config-Environment {
    # Start configure
    Write-ConfigLog "Setting autologon..." -ForegroundColor Yellow
    .\Set-AutoLogon -Domain $domain -Username $userName -Password $userPwd -Count 999

    # Turn off UAC
    Write-ConfigLog "Turn off UAC..." -ForegroundColor Yellow
    Set-ItemProperty -path  HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name "EnableLUA" -value "0"

    Write-ConfigLog "Enable WinRM"
    if (Test-WSMan -ComputerName $sutIp) {
        Write-ConfigLog "WinRM is running"
    }
    else {
        .\Enable-WinRM.ps1
    }

}

#------------------------------------------------------------------------------------------
# Function: Config-RDS
# Configure remote desktop services
#------------------------------------------------------------------------------------------
Function Config-RDS {
    # Enable Remote Desktop
    (Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1, 1) | Out-Null
    (Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
    Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true

    # Configure Network detection on RDP Server
    Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -name "SelectNetworkDetect" -value "0"
    
    # This value can enable the group policy: "Require use of specific security layer for remote (RDP) connections" to "Negotiate": this key needs gpupdate /force to take effect.
    Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -name "SecurityLayer" -value "1" -Type DWord

    # Allow automatic reconnection from clients: this key needs a reboot to take effect
    Set-ItemProperty -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -name "fDisableAutoReconnect" -value "0"

    # Force update the GPO to make the configuration work immediately to make sure all cases runs under the correct environment.
    gpupdate /Force
}

Function RestartAndResume {
    $NextStep = $Step + 1
    .\RestartAndRun.ps1 -ScriptPath $ScriptFileFullPath `
        -PhaseIndicator "-Step $NextStep" `
        -AutoRestart $true
}

#------------------------------------------------------------------------------------------
# Function: Activate-LicenseServer
# Activate the remote desktop license server
#------------------------------------------------------------------------------------------
function Activate-LicenseServer {
    $wmiTSLicenseObject = Get-WMIObject Win32_TSLicenseServer -computername $sutName
    $wmiTSLicenseObject.FirstName = "test"
    $wmiTSLicenseObject.LastName = "test"
    $wmiTSLicenseObject.Company = "test"
    $wmiTSLicenseObject.CountryRegion = "Albania"   # Just pick one randomly from the collection
    $wmiTSLicenseObject.Put()

    $wmiClass = ([wmiclass]"\\$($sutName)\root\cimv2:Win32_TSLicenseServer")

    $retryTimes = 3
    do {
        $wmiClass.ActivateServerAutomatic()

        $result = $wmiClass.GetActivationStatus().ActivationStatus
        Write-ConfigLog "Activation status: $result (0 = activated, 1 = not activated)"

        if ($result -eq 0) {
            break
        }

        $retryTimes--
        Start-sleep 5
    } while ($retryTimes -gt 0)

    if ($result -ne 0) {
        Write-ConfigLog "Activate license server failed after retrying 3 times."
    }
}

#------------------------------------------------------------------------------------------
# Function: Set-LicenseServer
# Set the license server name for RDP session host
#------------------------------------------------------------------------------------------
function Set-LicenseServer {
    $RDPSessionHost = gwmi -namespace "Root/CIMV2/TerminalServices" Win32_TerminalServiceSetting
    $RDPSessionHost.ChangeMode(2) ## Set the license type of the current Remote Desktop Session Host (RD Session Host) server; 2 stands for "Per device".
    $RDPSessionHost.SetSpecifiedLicenseServerList($sutName)
}

#------------------------------------------------------------------------------------------
# Function: Install-License
# Install a per device license on the activated license server
#------------------------------------------------------------------------------------------
function Install-License {
    $keypack = ([wmiclass]"\\$($sutName)\root\cimv2:Win32_TSLicenseKeyPack")
    # 1 is Agreeement Type: Enterprise Agreement
    # 1234567 is the agreeement number
    # 4 is product version: Windows 2012
    # 0 is product type: per device
    # 250 is license count
    $keypack.InstallAgreementLicenseKeyPack(1, 1234567, 4, 0, 250)
}

#------------------------------------------------------------------------------------------
# Function: Install-RDSFeature
# Install remote desktop services and the related features
#------------------------------------------------------------------------------------------
function Install-RDSFeature {
    Add-WindowsFeature -Name RDS-RD-Server -IncludeAllSubFeature
    Add-WindowsFeature -Name RDS-Licensing -IncludeAllSubFeature -IncludeManagementTools
}

#------------------------------------------------------------------------------------------
# Main Function
#------------------------------------------------------------------------------------------
Function Main {
    # Initialize configure environment
    Init-Environment

    switch ($Step) {
        1 { 
            # Start configure
            Config-Environment
            Install-RDSFeature
            RestartAndResume
        }
        2 { 
            Activate-LicenseServer
            Install-License
            Set-LicenseServer
            Config-RDS
            RestartAndResume
        }
        3 {
            Complete-Configure
        }
    }
}

Main

Pop-Location