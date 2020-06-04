##############################################################################################################
#
#  Script       : Clone Existing Azure VM
#  Description  : Clone an existing Azure VM
#  Author       : Irfan Hassan
#  Date         : 04/06/2020
#  Version      : 1.1.4
#
##############################################################################################################

## Prefix of the Existing VM (For Windows VMs keep this value at 13 or less characters)
$parentvmPrefix = ""

## Uncomment the below if you wish to use a different location to the existing VM
#$location = ""

## Prefix of the New VM
$vmPrefix = ""

## Resource group name of new VM
$newResourceGroupName = $vmPrefix + "-RG"

## Enter the name of an existing virtual network where virtual machine will be created
$virtualNetworkName = ""

## Enter the name of the existing virtual networks resource group name
$virtualNetworkRGName = ""

## name of the newly created vm
$virtualMachineName = $vmPrefix + "-vm"

## Provide the size of the virtual machine e.g. "Standard_D2s_v3"
$virtualMachineSize = ""

## Existing NSG Name
$parentnsgName = $parentvmPrefix + "-nsg"

## Uncomment the below and put the Name of the new NSG if you will not be using the existing one
#$nsgName = $vmPrefix + "-nsg"

## Subscription ID for Azure
$SubscriptionID = ""

## Connect to Azure Account
Connect-AzAccount

## Select a subscription
$context = Get-AzSubscription -SubscriptionId $SubscriptionID
Select-AzSubscription $context

## Select existing disks
$existingDisks = Get-AzDisk -Name $parentVMPrefix*

## Create a snapshot of each of the disks selected
Foreach ($disk in $existingDisks)
    {
        $parentResourceGroupName = $disk.ResourceGroupName
        $snapshotName = $disk.name + "-Snapshot"
        if (!$location)
            {
                $location = $disk.Location
            }
        $snapshot = New-AzSnapshotConfig `
        -SourceUri $disk.Id `
        -Location $location `
        -CreateOption copy

        New-AzSnapshot `
        -Snapshot $snapshot `
        -SnapshotName $snapshotName `
        -ResourceGroupName $parentresourceGroupName
    }

## Create the new Resource Group if it doesnt exist
Get-AzResourceGroup -Name $newResourceGroupName -ErrorAction SilentlyContinue -ErrorVariable newRGError
If ($newRGError)
    {
        New-AzResourceGroup -Name $newResourceGroupName -Location $location
    }

## Select newly created OS snapshot
$osSnapshot = Get-AzSnapshot -SnapshotName $parentVMPrefix*OS*

## Create a managed disk from the OS snapshot

$osSnapshotName = $osSnapshot.Name
$osDiskName = $vmPrefix + "-OSDisk1"
$diskSize = $osSnapshot.DiskSizeGB
$osStorageType = "Standard_LRS"
$snapshot = Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $osSnapshotName
$osDiskConfig = New-AzDiskConfig -Location $location -DiskSizeGB $diskSize -SkuName $osStorageType -CreateOption copy -SourceResourceId $snapshot.Id
$osDisk = New-AzDisk -Disk $osDiskConfig -ResourceGroupName $newResourceGroupName -Diskname $osDiskName

## Select newly created Data snapshots
$dataSnapshots = Get-AzSnapshot -SnapshotName $parentVMPrefix*data*

## Set the DataDisk No. to start from 0
$DatadiskNo = 1

## Create a managed disk from each snapshot
foreach ($snapshot in $dataSnapshots)
    {
        $snapshotName = $snapshot.Name
        $diskName = $vmPrefix + "-DataDisk" + $DatadiskNo
        $diskSize = $snapshot.DiskSizeGB
        $storageType = "Standard_LRS"
        $snapshot = Get-AzSnapshot -ResourceGroupName $parentResourceGroupName -SnapshotName $snapshotName
        $diskConfig = New-AzDiskConfig -Location $location -DiskSizeGB $diskSize -SkuName $storageType -CreateOption copy -SourceResourceId $snapshot.Id
        $disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $newResourceGroupName -Diskname $diskName
        $DatadiskNo++
    }

## Initialize virtual machine configuration
$VirtualMachine = New-AzVMConfig -VMName $virtualMachineName -VMSize $virtualMachineSize

## Select the newly created Datadisks
$vmDataDiskName = $vmPrefix + "-DataDisk"
$NewDataDisks = Get-AzDisk -Name $vmDataDiskName*

## Set the LUN to start from 0
$LUN = 0

## Add each disk with an incrementing LUN variable
foreach ($DataDisk in $NewDataDisks)
    {
        $VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $datadisk.Name -ManagedDiskId $DataDisk.Id -Lun "$LUN" -CreateOption "Attach"
        $LUN++
    }

$vmOSDiskName = $vmPrefix + "-OS"
$osDisk = Get-AzDisk -Name $vmOSDiskName* 

## Use the Managed Disk Resource Id to attach it to the virtual machine. Use OS type based on the OS present in the disk - Windows / Linux
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $osDisk.Id -CreateOption Attach -Windows

## Create a public IP 
$publicIp = New-AzPublicIpAddress -Name ($VirtualMachineName.ToLower()+'_ip') -ResourceGroupName $newResourceGroupName -Location $Location -AllocationMethod Static

## Get Existing NSG Information
$nsg = Get-AzNetworkSecurityGroup -Name $parentnsgName -ResourceGroupName $parentResourceGroupName

if ($nsgName)
    {
        ## Grab the rules of the existing NSG
        $nsgRules = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg

        ## Create the new NSG
        $newNsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $newResourceGroupName -Location $location

        ## Copy each rule from existing NSG to new NSG
        foreach ($nsgRule in $nsgRules)
            {
                Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $newNsg `
                    -Name $nsgRule.Name `
                    -Protocol $nsgRule.Protocol `
                    -SourcePortRange $nsgRule.SourcePortRange `
                    -DestinationPortRange $nsgRule.DestinationPortRange `
                    -SourceAddressPrefix $nsgRule.SourceAddressPrefix `
                    -DestinationAddressPrefix $nsgRule.DestinationAddressPrefix `
                    -Priority $nsgRule.Priority `
                    -Direction $nsgRule.Direction `
                    -Access $nsgRule.Access 
            }
        
        ## Set the Rules of the New NSG
        Set-AzNetworkSecurityGroup -NetworkSecurityGroup $newNsg
        
        ## Clear existing $nsg
        Clear-Variable nsg

        ## Set $nsg to new NSG
        $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $newResourceGroupName
    }

## Get VNET Information
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $virtualNetworkRGName

## Create NIC for the VM
$nic = New-AzNetworkInterface -Name ($VirtualMachineName.ToLower()+'_nic') -ResourceGroupName $newResourceGroupName -Location $Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id

## Set Azure Boot Diagnostics Off
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable

## Create the virtual machine with Managed Disk
New-AzVM -VM $VirtualMachine -ResourceGroupName $newResourceGroupName -Location $Location -DisableBginfoExtension

## Store the Public IP address of the VM
$publicIPConfig = Get-AzPublicIpAddress -ResourceGroupName $newResourceGroupName -Name $vmPrefix* 
$publicIPAddress = $publicIPConfig.IpAddress
$privateIPAddress = $nic.IpConfigurations.privateIPAddress

## Output connection details of the VM
Write-Output "VM Name            :  $virtualMachineName"
Write-Output "Public IP Address  :  $publicIPAddress"
Write-Output "Private IP Address :  $privateIPAddress"