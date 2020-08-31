## Readme
This script was created to automatically obtain dynamic Public IP addresses and update Source Addresses in defined NSGs with the updated Public IP address.

For authentication you require an App registration with permissions to see and edit NSGs in your subscription and the below details of the App registration.
- key
- clientId
- tenantId

This can be further automated by running the script as a Scheduled Task with any set trigger (preferably time based e.g. every 12 hours)

The method of defining the NSGs to be updated is via a variable followed by a wildcard (this may require changes based on your NSG naming convention)

---

## Usage
- To run as a one off without specifying any parameters beforehand (This will prompt you for the authentication details and the Rule name you want to update)
.\auto-update-nsg.ps1 

- To run as a one off without having to make any inputs update the auto-update-nsg.ps1 script with static entries of your authentication details and rule name (ln.13),(ln.14),(ln.15),(ln.16)
.\auto-update-nsg.ps1

- To run as a one off and specify the authentication details and rule name
.\auto-update-nsg.ps1 -key "Enter Key Here" -clientId "Enter ClientID Here" -tenantId "Enter TenantID Here" -existingRuleName "Enter Existing Rule Name Here"

- To install the script as a scheduled task for automatic run at 7am every day update the auto-update-nsg.ps1 script with static entries of your authentication details and rule name (ln.13),(ln.14),(ln.15),(ln.16) and specify the -install flag
.\auto-update-nsg.ps1 -install

---

## Planned Changes
- Add logging to track changes to all rules.
- Improve definement method.
- Improve data displayed on screen during runtime.

---


## Changelog
Below you will find changes made along with new issues found in each version.

### [v.1.0.0] 29/08/2020
#### Added
- Created auto-update-nsg.ps1

### [v.1.5.0] 31/08/2020
#### Added
- Ability to statically put the credentials for Azure as well as the script requesting them if you dont provide them statically or via parameters
- Added the -install option to set a scheduled task to run every day at 7am (only works when statically assigned credentials)
