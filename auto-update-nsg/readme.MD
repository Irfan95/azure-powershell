## Readme
This script was created to automatically obtain dynamic Public IP addresses and update Source Addresses in defined NSGs with the updated Public IP address.

For authentication you require an App registration with permissions to see and edit NSGs in your subscription and the below details of the App registration.
- key
- clientId
- tenantId

This can be further automated by running the script as a Scheduled Task with any set trigger (preferably time based e.g. every 12 hours)

The method of defining the NSGs to be updated is via a variable followed by a wildcard (this may require changes based on your NSG naming convention)

---

## Planned Changes
- Add logging to track changes to all rules.
- Improve definement method.
- Add a flag to be able to install a scheduled task when run via shell
- Improve data displayed on screen during runtime.

---


## Changelog
Below you will find changes made along with new issues found in each version.

### [v.1.0.0] 29/08/2020
#### Added
- Created auto-update-nsg.ps1