##############################################################################################################
#
#  Script       : Clone Existing Azure VM
#  Description  : Clone an existing Azure VM
#  Author       : Irfan Hassan
#  Date         : 14/03/2020
#  Version      : 1.0.1
#
##############################################################################################################

## Connect to Azure Account
Connect-AzAccount

## Select a subscription
$context = Get-AzSubscription -SubscriptionId ""
Select-AzSubscription $context

## Select existing disks by entering the prefix used for the disk names before the asterisk e.g. VMPrefix*
$ExistingDisks = Get-AzDisk -Name *

## Create a snapshot of each of the disks selected
Foreach ($Disk in $ExistingDisks)
    {
        $resourceGroupName = $Disk.ResourceGroupName
        $location = $Disk.Location
        $snapshotName = $Disk.name + "-Snapshot"

        $snapshot = New-AzSnapshotConfig `
        -SourceUri $Disk.Id `
        -Location $Disk.Location `
        -CreateOption copy

        New-AzSnapshot `
        -Snapshot $snapshot `
        -SnapshotName $snapshotName `
        -ResourceGroupName $resourceGroupName
    }

## Select newly created snapshots by entering the prefix used for the snapshots before the asterisk e.g. VMPrefix*
$ExistingSnapshots = Get-AzSnapshot -SnapshotName *

## Create a managed disk from each snapshot
foreach ($snapshot in $ExistingSnapshots)
    {
        $snapshotName = $snapshot.Name
        $resourceGroupName = $snapshot.ResourceGroupName
        
        ## Change the replace variables to match your prefix
        $diskName1 = $snapshotName -replace ("","")
        $diskName = $diskName1 -replace ("-Snapshot","")
        
        $storageType = "Standard_LRS"
        $location = $snapshot.Location
        $snapshot = Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName
        $diskConfig = New-AzDiskConfig -Location $location -SkuName $storageType -CreateOption copy -SourceResourceId $snapshot.Id
        $disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -Diskname $diskName
    }

## Enter the name of an existing virtual network where virtual machine will be created
$virtualNetworkName = ""

## Enter the name of the virtual machine to be created
$virtualMachineName = ""

## Provide the size of the virtual machine e.g. "Standard_D2s_v3"
$virtualMachineSize = ""

## Initialize virtual machine configuration
$VirtualMachine = New-AzVMConfig -VMName $virtualMachineName -VMSize $virtualMachineSize

## Select the newly created Datadisks by entering the prefix used for the disk names before the asterisk e.g. VMPrefix*
$NewDataDisks = Get-AzDisk -Name *

## Set the LUN to start from 0
$LUN = 0

## Add each disk with an incrementing LUN variable
foreach ($DataDisk in $NewDataDisks)
    {
        $VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $datadisk.Name -ManagedDiskId $DataDisk.Id -Lun "$LUN" -CreateOption "Attach"
        $LUN++
    }

## Select newly created snapshots by entering the prefix used for the snapshots before the asterisk e.g. VMPrefix*
$OSDisk = Get-AzDisk -Name * 

#Use the Managed Disk Resource Id to attach it to the virtual machine. Use OS type based on the OS present in the disk - Windows / Linux
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $OSDisk.Id -CreateOption Attach -Windows

#Create a public IP 
$publicIp = New-AzPublicIpAddress -Name ($VirtualMachineName.ToLower()+'_ip') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -AllocationMethod Dynamic

#Get VNET Information
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $virtualNetworkName

# Create NIC for the VM
$nic = New-AzNetworkInterface -Name ($VirtualMachineName.ToLower()+'_nic') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id

$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id

#Create the virtual machine with Managed Disk
New-AzVM -VM $VirtualMachine -ResourceGroupName $resourceGroupName -Location $snapshot.Location