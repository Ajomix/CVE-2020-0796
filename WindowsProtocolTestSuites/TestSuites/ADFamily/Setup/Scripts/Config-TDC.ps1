# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

##############################################################################
#
# Microsoft Windows Powershell Scripting
# File:           Config-TDC.ps1
# Purpose:        Configure Primary Domain Controller in Trusted Domain for Active Directory Family Test Suite.
# Requirements:   Windows Powershell 2.0
# Supported OS:   Windows Server 2008 R2, Windows Server 2012, Windows Server 2012 R2,
#                 Windows Server 2016, and later.
#
##############################################################################

##############################################################################
# Parameters:
# Help: whether to display the help information
# Step: Current step for configuration
##############################################################################

Param
(
    [alias("h")]
    [switch]
    $Help,

    [switch]
    $EnableDebugging,
    
    [int]
    $Step = 1,

    [String]
    $ConfigFile = "c:\temp\Protocol.xml"
)

#------------------------------------------------------------------------------------------
# Global Variables:
# ScriptFileFullPath: Full Path of this script file
# ScriptName:         File Name of this script file 
# ScriptPath:         File Path of this script file
# SignalFileFullPath: Full Path of the completion signal file for this script file
# LogFileFullPath:    Full Path of the log file for this script file
# Parameters:         Parameters read from the config file
#------------------------------------------------------------------------------------------
$ScriptFileFullPath      = $MyInvocation.MyCommand.Definition
$ScriptName              = [System.IO.Path]::GetFileName($ScriptFileFullPath)
$ScriptPath              = Split-Path $ScriptFileFullPath
$SignalFileFullPath      = "$ScriptPath\post.finished.signal"
$LogFileFullPath         = "$ScriptFileFullPath.log"
$Parameters              = @{}
$IsAzure                 = $false

try {
    [xml]$content = Get-Content $ConfigFile -ErrorAction Stop
    $currentCore = $content.lab.core
    if(![string]::IsNullOrEmpty($currentCore.regressiontype) -and ($currentCore.regressiontype -eq "Azure")){
        $IsAzure = $true;
        $SignalFileFullPath = "C:\PostScript.Completed.signal"
    }
}
catch {
    
}
#------------------------------------------------------------------------------------------
# Function: Display-Help
# Display the help messages.
#------------------------------------------------------------------------------------------
Function Display-Help()
{
    $helpmsg = @"
Post configuration script to configure Primary Domain Controller in Trusted Domain for Active Directory Family Test Suite.

Usage:
    .\Config-TDC.ps1 [-Step <step>] [-h | -help]

Step: Current step for configuration. The default value is 1.
help(h) : Display this help message.

"@
    Write-Output $helpmsg "`r`n"
    exit 0
}

#------------------------------------------------------------------------------------------
# Function: Start-ConfigLog
# Create log file and start logging
#------------------------------------------------------------------------------------------
Function Start-ConfigLog()
{
    if(!(Test-Path -Path $LogFileFullPath)){
        New-Item -ItemType File -path $LogFileFullPath -Force
    }
    Start-Transcript $LogFileFullPath -Append 2>&1 | Out-Null
}

#------------------------------------------------------------------------------------------
# Function: Write-ConfigLog
# Write information to log file
#------------------------------------------------------------------------------------------
Function Write-ConfigLog
{
    Param (
        [Parameter(ValueFromPipeline=$true)] $text,
        $ForegroundColor = "Green"
    )

    $date = Get-Date -f MM-dd-yyyy_HH_mm_ss
    Write-Output "[$date] $text"
}

#------------------------------------------------------------------------------------------
# Function: Read-ConfigParameters
# Read Config Parameters
#------------------------------------------------------------------------------------------
Function Read-ConfigParameters()
{
    Write-ConfigLog "Getting the parameters from config file..." -ForegroundColor Yellow
    if($IsAzure)
    {
        .\GetVmParametersByComputerName.ps1 -RefParamArray ([ref]$Parameters)
    } else {
    $VMName = .\GetVMNameByComputerName.ps1
        .\GetVmParameters.ps1 -VMName $VMName -RefParamArray ([ref]$Parameters)
    }
    $Parameters
}

#------------------------------------------------------------------------------------------
# Function: Init-Environment
# Start logging, check signal file, switch to script path and read the config parameters
#------------------------------------------------------------------------------------------
Function Init-Environment()
{
    # Start logging
    Start-ConfigLog

    # Start executing the script
    Write-ConfigLog "Executing [$ScriptName]..." -ForegroundColor Cyan

    # Check completion signal file. If signal file exists, exit with 0
    if(Test-Path -Path $SignalFileFullPath){
        Write-ConfigLog "The script execution has been completed." -ForegroundColor Red
        exit 0
    }

    # Switch to the script path
    Write-ConfigLog "Switching to $ScriptPath..." -ForegroundColor Yellow
    Push-Location $ScriptPath

    # Read the config parameters
    Read-ConfigParameters
}

#------------------------------------------------------------------------------------------
# Function: Proceed-ScriptWithRestart
# Restart computer and proceed the script to the next step
#------------------------------------------------------------------------------------------
Function Proceed-ScriptWithRestart
{
    $NextStep = $Step + 1

    # add a schedule task to execute the script next step after restart
    .\RestartAndRun.ps1 -ScriptPath $ScriptFileFullPath `
                        -PhaseIndicator "-Step $NextStep" `
                        -AutoRestart $true
}

#------------------------------------------------------------------------------------------
# Function: Remove-ScriptFromTask
# Remove the sceduled task to execute the script next step
#------------------------------------------------------------------------------------------
Function Remove-ScriptFromTask
{
    # remove the schedule task to execute the script next step after restart
    .\RestartAndRunFinish.ps1
}

#------------------------------------------------------------------------------------------
# Function: Complete-Configure
# Write signal file, stop the transcript logging and remove the scedule task
#------------------------------------------------------------------------------------------
Function Complete-Configure
{
    # Write signal file
    Write-ConfigLog "Write signal file`: post.finished.signal to hard drive."
    cmd /C ECHO CONFIG FINISHED > $SignalFileFullPath

    # Ending script
    Write-ConfigLog "Config finished."
    Write-ConfigLog "EXECUTE [$ScriptName] FINISHED (NOT VERIFIED)." -ForegroundColor Green
    Stop-Transcript

    # remove the schedule task to execute the script next step after restart
    .\RestartAndRunFinish.ps1
}

#------------------------------------------------------------------------------------------
# Function: Config-Phase1
# Configure the environment phase 1:
# 1.  Set execution policy as unrestricted
# 2.  Set network configurations, for example, ip addresses, subnet mask, gateway and dns
# 3.  Set autologon
# 4.  [MS-ADTS-Security] Turn off UAC
# 5.  Promote Domain Controller as a Primary Domain Controller in the trusted domain
# 6.  [MS-ADTS-Security] Set security level
#------------------------------------------------------------------------------------------
Function Config-Phase1()
{
    Write-ConfigLog "Entering Phase 1..."

    # Set execution policy as unrestricted
    Write-ConfigLog "Setting execution policy..." -ForegroundColor Yellow
    .\Set-ExecutionPolicy-Unrestricted.ps1
    if(-not $IsAzure)
    {
        # Set network configurations
        Write-ConfigLog "Setting network configurations..." -ForegroundColor Yellow
        .\Set-NetworkConfiguration.ps1 -IPAddress $Parameters["ip"] -SubnetMask $Parameters["subnet"] -Gateway $Parameters["gateway"] -DNS ($Parameters["dns"].Split(';'))
    }
    # Set autologon
    Write-ConfigLog "Setting autologon..." -ForegroundColor Yellow
    .\Set-AutoLogon.ps1 -Domain $Parameters["domain"] -Username $Parameters["username"] -Password $Parameters["password"]

    # Turn off UAC
    Write-ConfigLog "Turn off UAC..." -ForegroundColor Yellow
    .\Turnoff-UAC.ps1

    # Promote Domain Controller
    Write-ConfigLog "Promoting this computer to a secondary domain controller..." -ForegroundColor Yellow
    .\WaitFor-ComputerReady.ps1 -computerName $Parameters["trusttargetserver"] -usr $Parameters["trusttargetuser"] -pwd $Parameters["trusttargetpwd"]
    .\PromoteDomainController.ps1 -DomainName $Parameters["domain"] -AdminPwd $Parameters["password"] -AdminUser $Parameters["username"]

    # Set security level
    Write-ConfigLog "Setting security level..." -ForegroundColor Yellow  
    .\Set-SecurityLevel.ps1
}

#------------------------------------------------------------------------------------------
# Function: Config-Phase2
# Configure the environment phase 2:
# 1.  Turn off firewall
# 2.  Set domain admin account password cannot be changed and never expires
# 3.  Set password change, netlogon, create object rights in registry key and group policy: 
#      (a) [MS-DRSR][MS-FRS2] disable auto password change (Registry Key)
#      (b) [MS-NRPC] refuse password change request (Registry Key)
#      (c) [MS-NRPC] configure netlogon service to depend on the DNS service (Registry Key)
#      (d) [MS-DRSR] disable auto password change (Group Policy)
#      (e) [MS-ADTS-LDAP] set only domain admins group can create computer object (Group Policy)
# 4.  [MS-ADTS-Schema][MS-NRPC] Create bidirectional forest trust on local side
# 5.  [MS-ADTS-Schema][MS-NRPC] Create bidirectional forest trust on remote side by triggering Phase 3 of Config-PDC.ps1 on <PDC>
# 6.  Get and log operating system version
# 7.  Get and log netbiosName from Domain Service domain object <DomainNc>
# 8.  [MS-ADTS-Schema][MS-NRPC] Verify the bidirectional forest trust
# 9.  Add remote administrator from the trusted domain to local builtin administrators group
# 10. Register Windbg dbgsrv for debugging purpose
#------------------------------------------------------------------------------------------
Function Config-Phase2()
{
    Write-ConfigLog "Entering Phase 2..."

    # Turn off firewall
    Write-ConfigLog "Turn off firewall..." -ForegroundColor Yellow
    .\Disable_Firewall.ps1

    # Set domain admin account password cannot be changed and never expires
    Write-ConfigLog "Setting domain admin account password cannot be changed and never expires..." -ForegroundColor Yellow
    .\Set-AdUserPwdPolicy.ps1 -Domain $Parameters["domain"] -Name $Parameters["username"] -Password $Parameters["password"]

    # Set password change, netlogon, rights in registry key and group policy
    Write-ConfigLog "Setting password change, netlogon, create object rights in registry key and group policy..." -ForegroundColor Yellow
    .\Set-NetlogonRegKeyAndPolicy.ps1 -IsDc

    # Create bidirectional forest trust on local side
    Write-ConfigLog "Creating forest trust relationship on local side..." -ForegroundColor Yellow
    .\CreateLocalSideForestTrust.ps1 -TargetForestName $Parameters["trusttargetdomain"] -TrustPassword $Parameters["trustpassword"]

    # Create bidirectional forest trust on remote side by triggering Phase 3 of Config-PDC.ps1 on <PDC>
    Write-ConfigLog "Creating forest trust relationship on remote side, trigger Phase3 of Config-PDC.ps1..." -ForegroundColor Yellow
    .\WaitFor-ComputerReady.ps1 -computerName $Parameters["trusttargetserver"] -usr $Parameters["trusttargetuser"] -pwd $Parameters["trusttargetpwd"]
    .\Execute-RemoteScript.ps1 -RemoteHost $Parameters["trusttargetserver"] -Username $Parameters["trusttargetuser"] -Password $Parameters["trusttargetpwd"] `
                               -ScriptPath $ScriptPath -ScriptName ".\Config-PDC.ps1" -ScriptArgs "-Step 3"

    # Get OS Version
    Write-ConfigLog "Getting Operating System Version..." -ForegroundColor Yellow
    $OsVersion = .\Get-OSVersionForADTests.ps1 -log

    # Get and log netbiosName from Domain Service domain object <DomainNc>
    Write-ConfigLog "Getting Domain Netbios name..." -ForegroundColor Yellow
    .\Get-DomainNetbiosName.ps1 -Domain $Parameters["domain"] -log

    # Verify the bidirectional forest trust
    Write-ConfigLog "Verifying the bidirectional forest trust..." -ForegroundColor Yellow
    $Timeout = 300
    do {
        Try {
            Sleep 60
            $WarningMessage = $null
            .\Verify-ForestTrust.ps1 -RemoteForest $Parameters["trusttargetdomain"] -RemoteUser $Parameters["trusttargetuser"] -RemotePassword $Parameters["trustpassword"]
        }
        Catch {
            $WarningMessage = $_
        }
    } while (($WarningMessage -ne $null) -and ($Timeout -= 60))

    # Add remote administrator from the trusted domain to local builtin administrators group
    Write-Host "Adding remote administrator from the trusted domain to local builtin Administrators group..."
    .\Add-AdRemoteUserToLocalGroup.ps1 -RemoteDomain $Parameters["trusttargetdomain"] -RemoteUsername $($Parameters["trusttargetuser"].ToString().Split('\')[1]) -LocalGroups @('Administrators')
    
    # Register Windbg dbgsrv
    if($EnableDebugging)
    {
        Write-ConfigLog "Registering Windbg dbgsrv..." -ForegroundColor Yellow
        .\Register-DbgSrv.ps1
    }
}

#------------------------------------------------------------------------------------------
# Function: Config-Environment
# Control the overall workflow of all configuration phases
#------------------------------------------------------------------------------------------
Function Config-Environment
{
    # Start configure
    switch($Step)
    {
        1 { Config-Phase1; Proceed-ScriptWithRestart; }
        2 { Config-Phase2; Proceed-ScriptWithRestart; }
        3 { Complete-Configure; }
        default
        {
            Write-ConfigLog "Fail to execute the script!" -ForegroundColor Red
            break
        }
    }
}

#------------------------------------------------------------------------------------------
# Main Function
#------------------------------------------------------------------------------------------
Function Main
{
    # Display help information
    if($Help)
    {
        Display-Help
        return
    }

    # Initialize configure environment
    Init-Environment    

    # Complete configure
    Config-Environment
}

Main