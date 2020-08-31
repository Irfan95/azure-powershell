##############################################################################################################
#
#  Script       : auto-update-nsg 
#  Description  : Automatically update NSGs with Public IP
#  Author       : Irfan Hassan
#  Date         : 31/08/2020
#  Version      : 1.5.0
#
##############################################################################################################

[CmdletBinding()]
Param (
    [string] $key = "Enter Key here",
    [string] $clientId = "Enter ClientID here",
    [string] $tenantId = "Enter TenantID here",
    [string] $existingRuleName = "Enter Rule Name here",
    [switch] $install
)

## If the information wasnt provided at Option level or statically above then it will request it below.
if ($key -eq "Enter Key here")
    {
        $key = Read-Host "Please enter the Key provided to access Azure Resources"
    }

if ($clientId -eq "Enter ClientID here")
    {
        $clientId = Read-Host "Please enter the Client ID provided to access Azure Resources"
    }

if ($tenantId -eq "Enter TenantID here")
    {
        $tenantId = Read-Host "Please enter the Tenant ID provided to access Azure Resources"
    }

if ($existingRuleName -eq "Enter Rule Name here")
    {
        $existingRuleName = Read-Host "Please enter the Rule Name you wish to apply the Static IP changes to"
    }

## Create a Task Schedule to run at a set interval
if ($install -eq $true)
    {
        ## Copy the current script to the user profile
        if ($psise)
            {
                $ScriptDir = $psise.CurrentFile.FullPath
                Copy-Item -Path $ScriptDir -Destination "$env:USERPROFILE\Documents\auto-update-nsg.ps1" -Force
            }
        elseif ($PSCommandPath -eq "") 
            {
                Add-Type -AssemblyName System.Windows.Forms
                $CurrentScript = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                        Title = "Please select the auto-update-nsg.ps1 file" 
                        InitialDirectory = [Environment]::GetFolderPath('Desktop') 
                        Filter = 'PowerShell Scripts (*.ps1)|*.ps1'    
                    }
                $null = $CurrentScript.ShowDialog()
                $ScriptDir = $CurrentScript.FileName

                Copy-Item -Path $ScriptDir -Destination "$env:USERPROFILE\Documents\auto-update-nsg.ps1" -Force
            }
        else 
            {
                $ScriptDir = $PSCommandPath
                Copy-Item -Path $ScriptDir -Destination "$env:USERPROFILE\Documents\auto-update-nsg.ps1" -Force
            }
        
        ## The name of the scheduled task
        $TaskName = "auto-update-nsg"

        ## The description of the task
        $TaskDesc = "This task was created to automatically update all NSG rules on Azure with the current Public IP address"

        ## The Task Action command
        $TaskCommand = "C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"

        ## The PowerShell script to be executed
        $TaskScript = "$env:USERPROFILE\Documents\auto-update-nsg.ps1"

        ## The Task Action command argument
        $TaskArg = "-Executionpolicy Bypass -file " + "`"$TaskScript" + '"'

        ## This is where the Actions taken will be specified
        $Action = New-ScheduledTaskAction -Execute $TaskCommand -Argument $TaskArg

        ## This is where the Trigger will be specified
        $Trigger = New-ScheduledTaskTrigger -Daily -At 7am

        ## This is where the Settings/Conditions will be specified
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd 

        ## This is where the Scheduled Task is created
        Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName $TaskName -Description $TaskDesc -Settings $Settings -User System -RunLevel Highest
    }

## Authenticate to Azure
$securePassword = $key | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $clientId, $securePassword
Add-AzAccount -Credential $cred -TenantId $tenantId -ServicePrincipal

## Gather New Public IP
$publicIpWebRequest = (Invoke-WebRequest -Uri "http://ipinfo.io/ip" -UseBasicParsing).Content
$newPublicIp = $publicIpWebRequest.Trim()

## Get all NSG Rules
$securityRules = Get-AzNetworkSecurityGroup | Select-Object SecurityRules -ExpandProperty SecurityRules 

## Gather all the current NSG rules into Array
foreach ($Rule in $securityRules)
    {
        If ($Rule.Name -like "$existingRuleName*")
            {
                ## Set Variable for Rule Name
                $ruleName = $Rule.Name
                
                ## Set Variable for Current IP address on NSG rule
                $ruleIP = $Rule.SourceAddressPrefix

                ## Set Variable for Desc on the NSG rule
                $ruleDesc = $Rule.Description

                ## Set Variable for Protocol on the NSG rule
                $ruleProto = $Rule.Protocol

                ## Set Variable for Source Port Range on the NSG rule
                $ruleSrcPrtRng = $Rule.SourcePortRange

                ## Set Variable for Destination Port Range on the NSG rule
                $ruleDstPrtRng = $Rule.DestinationPortRange

                ## Set Variable for Destination Address Prefix on the NSG rule
                $ruleDstAddPre = $Rule.DestinationAddressPrefix

                ## Set Variable for Access on the NSG rule
                $ruleAccess = $Rule.Access

                ## Set Variable for Priority on the NSG rule
                $rulePriority = $Rule.Priority

                ## Set Variable for Direction on the NSG rule
                $ruleDirection = $Rule.Direction

                ## Set Varibale for the NSG name the Rule is attached to
                $ruleNSG = ($Rule.Id).Split("/")[-3]

                ## Set Variable for the Resource Group the NSG belongs to.
                $ruleRG = ($Rule.Id).Split("/")[-7]

                if ($ruleDesc -eq $null)
                    {
                        $ruleDesc = "No Desc"
                    }

                ## Writes all above into table.
                $Rules += @(
                    [pscustomobject]@{Name=$ruleName;nsgRg=$ruleRG;Ip=$ruleIP;nsgName=$ruleNSG;Desc=$ruleDesc;Proto=$ruleProto;SrcPrtRng=$ruleSrcPrtRng;DstPrtRng=$ruleDstPrtRng;Access=$ruleAccess;Priority=$rulePriority;Direction=$ruleDirection;DstAddPre=$ruleDstAddPre}
                )
            }
    }

## Update all Rules with existing rules and new Public IP
foreach ($nsgRule in $Rules)
    {
        $nsg = Get-AzNetworkSecurityGroup -Name $nsgRule.nsgName -ResourceGroupName $nsgRule.nsgRg
        $nsg | Get-AzNetworkSecurityRuleConfig -Name $nsgRule.Name
        Set-AzNetworkSecurityRuleConfig -Name $nsgRule.Name `
        -NetworkSecurityGroup $nsg `
        -SourceAddressPrefix $newPublicIp `
        -Description $nsgRule.Desc `
        -Protocol $nsgRule.Proto `
        -SourcePortRange $nsgRule.SrcPrtRng `
        -DestinationPortRange $nsgRule.DstPrtRng `
        -DestinationAddressPrefix $nsgRule.DstAddPre `
        -Access $nsgRule.Access `
        -Priority $nsgRule.Priority `
        -Direction $nsgRule.Direction

        Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg
    }