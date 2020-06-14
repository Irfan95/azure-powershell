## Readme
This script will obtain the values below from an existing VM and create a new VM. (Windows only)
- VM Size
- VM Location
- OS Disk
- Data Disks
- NSG rules
- Existing Subnet
- NIC attributes

To use this script you will need to fill out the following variables on lines (ln:12) (ln:15) (ln:18) (ln:21)
This will create the following resources using the details above and naming convention below
Virtual Machine         : Prefix-vm
Resource Group          : Prefix-rg
OS Disk                 : Prefix-OSDisk1
Data Disk               : Prefix-DataDisk# < # is an incremental value for each disk attached to existing vm
Network Security Group  : Prefix-nsg
Public IP Address       : VMName-pip
NIC                     : VMName-nic

---

## Changelog
Below you will find changes made along with new issues found in each version.

---

### [v.1.0.0] 13/03/2020
#### Added
- Created azure-clone-vm.ps1.

#### Known Issues
- [#1] Resources dont always get discovered. (ln:19) (ln:40) (ln:72) (ln:85)
- [#2] Timeout when attempting to contact vm extensions once vm is created. (ln:102)
- [#3] NSG is not attached/created.

---

### [v1.0.1] 14/03/2020
#### Removed
- Removed quotes from (ln:19) (ln:40) (ln:72) (ln:85) to improve discovery of resources.

#### Resolved
- [#1] Resource discovery has been improved with the removed quotes.

---

### [v1.1.1] 14/03/2020
#### Added
- Added variable to create and store vm in new Resource Group.
- Create new Resource Group if it doesnt exist.
- Moved all variables to top of script to make modifications easier.
- Added prefix variable to name new resources more consistently.

---

### [v1.1.2] 15/03/2020
#### Added
- Added SubscriptionID as a variable at the start
- Added Output after script completion to display connection details

---

### [v1.1.3] 15/03/2020
#### Added
- Added Private IP address output at end of script as per Issue #1

---

### [v1.1.4] 04/06/2020
#### Added
- Added option to duplicate NSG to avoid using existing resources if required.
- Disabled Diagnostics Account usage on VM
- Disabled the Background Info extension on VM

#### Resolved
- [#3] NSG is now created using a duplication of the existing NSG.
- [#4] New-AzVM wouldnt return a success but now resolved with -DisableBginfoExtension switch and disabled Diagnostic Account usage

---

### [v2.0.0] 14/06/2020
#### Added
- Location is automatically set from existing VMs Location
- VM size is automatically set from existing VMs size
- New VM is automatically attached to same network existing VM is attached to
- Data disks will now be set in the same LUN order as existing VM
- NSG is now obtained from the existing NIC

#### Known Issues
- [#5] Warning when creating new Public IP w/ regards to a command change

---