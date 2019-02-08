# intune-automatic-selective-wipe

Perform an Automatic Selective Wipe on Devicecs registered to Intune App Protection on the Last Working Day of the user

You can use this solution to:
* Automatically wipe ManagedAppRegistrations from Devices on the Last Working Day of an Employee based on the AccountExpiry attribute

# Prerequisites
* This script should be executed/scheduled in a machine running PowerShell v5.0 and above
* Optionally you should install Credential Manager 2.0 from PowerShell Gallery. Link to repository given below under Additional References
* If you are not going with Credential Manager 2.0, User Credential should be passed to the script in a differnt way either clear text or encrypted
* The Native Azure AD Client Application and the account you specify should have DirectoryReadAccess & Intune ReadWriteAcess. Refer documentation links below
* Attribute AccountExpiry from On Premise Active Directory should be synced to Azure AD as a Directory Extension

# Getting Started
After the prerequisites are installed or met, perform the following steps to use these scripts:
* Download the contents of the repositories to your local machine.
* Extract the files to a local folder (e.g. c:\intune-automatic-selective-wipe) on any machine
* Either manually run this script or schedule the script using Task Scheduler
* After installing Credential Manager 2.0, run the below cmdlet in PowerShell to save the credentials to Windows Credential Manager

```

New-StoredCredential -Target IntuneWipe -UserName 'admin@domain.com' -Password 'Password' -Persist LocalMachine | Out-Null

```

* You need to update the script with the client_id & tenant_id before scheduling the script. To update client_id, navigate to line # 167 in the code. To update tenant_id navigate to line # 186 in the code.

```

client_id = "5267372f-f7bc-4570-a4b2-28cb7e66646a"  #line # 167
$tenantID = "69a5c584-5bce-450a-9ee2-4cf417193ebd"  #line # 186

```

# Questions and comments.
Do you have any questions about our projects? Do you have any comments or ideas you would like to share with us?
We are always looking for great new ideas. You can send your questions and suggestions to us in the Issues section of this repository or contact us at ``contact@attosol.com``.

# Additional Resources
* [Deploy AIP Scanner](https://docs.microsoft.com/en-us/azure/information-protection/deploy-use/deploy-aip-scanner)
* [AIP Scanner Public Preview](https://cloudblogs.microsoft.com/enterprisemobility/2017/10/25/azure-information-protection-scanner-in-public-preview/)
* [Azure AD Connect Directory extensions](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-sync-feature-directory-extensions)
* [Credential Manager 2.0](https://www.powershellgallery.com/packages/CredentialManager/2.0)
* [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/overview)
* [Microsoft Graph API Intune Wipe](https://github.com/microsoftgraph/powershell-intune-samples/blob/master/AppProtectionPolicy/ManagedAppPolicy_Wipe.ps1)
* [Microsoft Graph API Read User](https://docs.microsoft.com/en-us/graph/api/user-get?view=graph-rest-1.0)
* [Microsoft Graph API Read Registrations](https://docs.microsoft.com/en-us/graph/api/intune-mam-managedappregistration-list?view=graph-rest-1.0)
