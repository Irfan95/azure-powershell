# Readme
This script will create clone disks of the selected parent VM and generate a VM with those newly cloned disks.

---

# CHANGELOG
Below you will find changes made along with new issues found in each version.

---

## [v.1.0.0] 13/03/2020
### Added
- Created azure-clone-vm.ps1

### Known Issues
- [#1] Resources dont always get discovered (ln:19) (ln:40) (ln:72) (ln:85)
- [#2] Timeout when attempting to contact vm extensions once vm is created. (ln:102)
- [#3] NSG doesnt get created.

---

## [v1.0.1] 14/03/2020
### Removed
- Removed quotes from (ln:19) (ln:40) (ln:72) (ln:85) to improve discovery of resources

### Resolved
- [#1] Resource discovery has been improved with the removed quotes

---
