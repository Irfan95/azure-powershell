##############################################################################################################
#
#  Script       : Clone Existing Azure VM
#  Description  : Clone an existing Azure VM
#  Author       : Irfan Hassan
#  Date         : 14/06/2020
#  Version      : 2.0.0
#
##############################################################################################################

## Name of the VM you want to clone
$existingVMName = ""

## Resource group that contains the VM you want to clone
$existingRg = ""

## Prefix of the New VM resources (Keep this value 13 characters or less)
$vmPrefix = ""

## Subscription ID for Azure
$SubscriptionID = ""

## Connect to Azure Account
Connect-AzAccount

## Select a subscription
$context = Get-AzSubscription -SubscriptionId $SubscriptionID
Select-AzSubscription $context

## Set Virtual Machine Name
$virtualMachineName = $vmPrefix + "-vm"

## Set new NSG Name
$nsgName = $vmPrefix + "-nsg"

## Gets details of existing VM
$existingVm = Get-AzVM -Name $existingVMName -ResourceGroupName $existingRG

## Gets location of existing VM
$location = $existingVm.Location

## Set new Resource Group name
$newResourceGroupName = $vmPrefix + "-rg"

## Create a new Resource Group if it doesnt exist
Get-AzResourceGroup -Name $newResourceGroupName -ErrorAction SilentlyContinue -ErrorVariable newRGError
If ($newRGError)
    {
        New-AzResourceGroup -Name $newResourceGroupName -Location $location
    }

## Gets VM size of existing VM
$vmSize = $existingVm.HardwareProfile | Select-Object VmSize -ExpandProperty VmSize

## Get Nic details from existing VM
$existingNic = $existingVm.NetworkProfile | Select-Object NetworkInterfaces -ExpandProperty NetworkInterfaces

## Select the existing Nic via ID
$RefNic = Get-AzNetworkInterface -ResourceId $existingNic.Id

## Select the Subnet the existing vm is attached to (this is to get the id when attaching new VM) $subnet.Id
$subnet = $RefNic.IpConfigurations | Select-Object subnet -ExpandProperty subnet

## Gets the details of the OSdisk attached to the existing VM (Use .id)
$existingOsDisk = $existingVm.StorageProfile.OsDisk.ManagedDisk

## Set Snapshot name for existing OSdisk
$ossnapshotName = $existingVm.StorageProfile.OsDisk.Name + "-Snapshot"

## Creates Snapshot config
$osSnapshot = New-AzSnapshotConfig `
-SourceUri $existingOsDisk.Id `
-Location $location `
-CreateOption copy

## Creates Snapshot of OS disk
New-AzSnapshot `
-Snapshot $osSnapshot `
-SnapshotName $ossnapshotName `
-ResourceGroupName $existingRg

## Get OS Disk snapshot details
$osSnapshot = Get-AzSnapshot -SnapshotName $ossnapshotName -ResourceGroupName $existingRg

## Create new Managed OS Disk via existing snapshot
$osDiskName = $vmPrefix + "-OSDisk1"
$diskSize = $osSnapshot.DiskSizeGB
$osStorageType = $osSnapshot.Sku | Select-Object Name -ExpandProperty Name
$snapshot = Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $osSnapshotName
$osDiskConfig = New-AzDiskConfig -Location $location -DiskSizeGB $diskSize -SkuName $osStorageType -CreateOption copy -SourceResourceId $snapshot.Id
New-AzDisk -Disk $osDiskConfig -ResourceGroupName $newResourceGroupName -Diskname $osDiskName
$newosDisk = Get-AzDisk -DiskName $osDiskName -ResourceGroupName $newResourceGroupName

## Gets the details of the Datadisks attached to the existing VM
$existingdataDisks = $existingVm.StorageProfile.DataDisks

## Create Snapshot of each Data Disk
Foreach ($disk in $existingdataDisks)
    {
        $diskName = $disk.Name
        $snapshotName = $diskName + "-Snapshot"
        $diskId = $disk.ManagedDisk.Id
        $snapshot = New-AzSnapshotConfig `
        -SourceUri $diskId `
        -Location $location `
        -CreateOption copy

        New-AzSnapshot `
        -Snapshot $snapshot `
        -SnapshotName $snapshotName `
        -ResourceGroupName $existingRg

        $dataSnapshot = Get-AzSnapshot -SnapshotName $snapshotName -ResourceGroupName $existingRg
        $datasnapshotSku = $dataSnapshot.Sku | Select-Object Name -ExpandProperty Name

        $diskName = $vmPrefix + "-DataDisk" + "-" + ($disk.LUN + "1")

        $dataDisks += @(
            [pscustomobject]@{DataDiskName=$diskName;DataDiskSnapshotName=$snapshotName;LUN=$disk.Lun;ID=$dataSnapshot.Id;DiskSizeGB=$dataSnapshot.DiskSizeGB;Sku=$datasnapshotSku;}
        )
    }

## Create a managed disk from each snapshot
foreach ($dataDisk in $dataDisks)
    {
        $snapshotName = $dataDisk.DataDiskSnapshotName
        $diskName = $datadisk.DataDiskName
        $diskSize = $dataDisk.DiskSizeGB
        $storageType = $dataDisk.Sku
        $diskConfig = New-AzDiskConfig -Location $location -DiskSizeGB $diskSize -SkuName $storageType -CreateOption copy -SourceResourceId $dataDisk.ID
        $disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $newResourceGroupName -Diskname $diskName
        $newdisk = Get-AzDisk -DiskName $diskName -ResourceGroupName $newResourceGroupName
        $newdataDisks += @(
            [pscustomobject]@{DataDiskName=$diskName;LUN=$dataDisk.Lun;ID=$newdisk.Id}
        )
    }

## Initialize virtual machine configuration
$VirtualMachine = New-AzVMConfig -VMName $virtualMachineName -VMSize $vmSize

## Add OS Disk to new VM
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $newosDisk.Id -CreateOption Attach -Windows 

## Add each Data Disk to new VM
foreach ($newdataDisk in $newdataDisks)
    {
        $VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $newdataDisk.DataDiskName -ManagedDiskId $newdataDisk.Id -Lun $newdataDisk.LUN -CreateOption "Attach"
    }

## Create a new Public IP 
$publicIp = New-AzPublicIpAddress -Name ($virtualMachineName.ToLower()+'-pip') -ResourceGroupName $newResourceGroupName -Location $Location -AllocationMethod Static

## Obtains the Id of the NSG attached to existing VM
$nsgId = $RefNic.NetworkSecurityGroup.Id

## Obtains the NSG Name from the ID
$existingnsgName = $nsgId.Split("/")[-1]

$existingnsgRg = $nsgId.Split("/")[-5]

## Get Existing NSG Information
$nsg = Get-AzNetworkSecurityGroup -Name $existingnsgName -ResourceGroupName $existingnsgRg

## Grab the rules of the existing NSG
$nsgRules = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg
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

## Create NIC for the VM
$nic = New-AzNetworkInterface -Name ($VirtualMachineName.ToLower()+'-nic') -ResourceGroupName $newResourceGroupName -Location $Location -SubnetId $subnet.Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

## Attach NIC to the new VM
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
Write-Output "Virtual Machine Name :  $virtualMachineName"
Write-Output "Public IP Address    :  $publicIPAddress"
Write-Output "Private IP Address   :  $privateIPAddress"