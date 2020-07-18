##############################################################################################################
#
#  Script       : Update NSG rules (Manual)
#  Description  : Update NSG rules with new Public IP
#  Author       : Irfan Hassan
#  Date         : 18/07/2020
#  Version      : 1.0.0
#
##############################################################################################################

## Variable for Name of User
$FirstName = ""

## Variable for Initials of User
$Initials = ""

## New Public IP address to assign to NSGs
$ipAddress = ""

## Subscription ID for Azure
$subscriptionID = ""

## Connect to Azure
Connect-AzAccount

## Select a subscription
$context = Get-AzSubscription -SubscriptionId $subscriptionID
Select-AzSubscription $context

######################################################################

## Get all Network Security Groups
$securityRules = Get-AzNetworkSecurityGroup | Select SecurityRules -ExpandProperty SecurityRules 

foreach ($Rule in $securityRules)
    {
        If (($Rule.Name -like "*$Initials*") -or ($Rule.Name -like "*$FirstName*"))
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

foreach ($nsgRule in $Rules)
    {
        $nsg = Get-AzNetworkSecurityGroup -Name $nsgRule.nsgName -ResourceGroupName $nsgRule.nsgRg
        $nsg | Get-AzNetworkSecurityRuleConfig -Name $nsgRule.Name
        Set-AzNetworkSecurityRuleConfig -Name $nsgRule.Name `
        -NetworkSecurityGroup $nsg `
        -SourceAddressPrefix $ipAddress `
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

#$Rules = $null
