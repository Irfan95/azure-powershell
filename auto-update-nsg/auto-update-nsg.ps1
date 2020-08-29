##############################################################################################################
#
#  Script       : auto-update-nsg 
#  Description  : Automatically update NSGs with Public IP
#  Author       : Irfan Hassan
#  Date         : 29/08/2020
#  Version      : 1.0.0
#
##############################################################################################################

## Authentication details
$key      = ""
$clientId = ""
$tenantId = ""

## Enter the wildcard value of the existing NSG Rule names (* added in script)
$existingRuleName = ""

## Gather New Public IP
$publicIpWebRequest = (Invoke-WebRequest -Uri "http://ipinfo.io/ip" -UseBasicParsing).Content
$newPublicIp = $publicIpWebRequest.Trim()

## Authenticate to Azure
$securePassword = $key | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $clientId, $securePassword
Add-AzAccount -Credential $cred -TenantId $tenantId -ServicePrincipal

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