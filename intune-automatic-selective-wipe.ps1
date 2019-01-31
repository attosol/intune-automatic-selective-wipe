#
# attosol-autoselective-wipe.ps1
#

<#
.SYNOPSIS
    Automatic Selective Wipe for Intune ManagedAppRegistered Devices on the Last Working Day of an Employee.

.DESCRIPTION
    You can use this script to:
        * Automatically wipe ManagedAppRegistrations from Devices on the Last Working Day of the Employee(AccountExpiry)
        * View Wipe Reports

    # Prerequisites
        * This script should be executed/scheduled in a machine running PowerShell v5.0 and above
        * Optionally you should Install Credential Manager 2.0 from PowerShell Gallery. Link to repository given below
        * If you are not going with Credential Manager 2.0, User Credential should be passed to the script in a differnt way which you can figure out
        * The Native Azure AD Client Application should have DirectoryReadAccess & Intune ReadWriteAcess. Refer documentation links below
        * Attribute AccountExpiry from On Premise Active Directory should be synced to Azure AD as a Directory Extension

.EXAMPLE
    # Getting Started
        After the prerequisites are installed or met, perform the following steps to use these scripts:
        * Download the contents of the repositories to your local machine.
        * Extract the files to a local folder (e.g. c:\attosol-autoselective-wipe) on any machine
        * Either manually run this script or schedule the script using Task Scheduler

.NOTES
    # Questions and comments.
        Do you have any questions about our projects? Do you have any comments or ideas you would like to share with us?
        We are always looking for great new ideas. You can send your questions and suggestions to us in the Issues section of this repository or contact us at contact@attosol.com.

        Author:         Noble K Varghese
        Version:        1.0
        Creation Date:  17-January-2019
        Purpose/Change: Automatic Selective Wipe for Intune App Protection based on AccountExpiry

.LINK
    # Additional Resources
        * https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-sync-feature-directory-extensions
        * https://www.powershellgallery.com/packages/CredentialManager/2.0
        * https://docs.microsoft.com/en-us/graph/overview
        * https://github.com/microsoftgraph/powershell-intune-samples/blob/master/AppProtectionPolicy/ManagedAppPolicy_Wipe.ps1
        * https://docs.microsoft.com/en-us/graph/api/user-get?view=graph-rest-1.0
        * https://docs.microsoft.com/en-us/graph/api/intune-mam-managedappregistration-list?view=graph-rest-1.0
#>

##################################################################

#region Functions   

#region Write-Log
Function Write-Log([string]$logFile, [string]$activity, [string]$category, [string] $message) {
    
    Add-Content -Path .\logs\$logFile -Value "[$([DateTime]::Now)]`t[$($activity)]`t[$($category)]`t[$($message)]" -Encoding UTF8
}
#endregion

##################################################################

#region Get-AzureADDetails
Function Get-AzureADDetails() {

    try {

        $graphApiVersion = "Beta"
        $DCP_resource = "users"

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"

        $allUsers = (Invoke-RestMethod -Uri $uri -Headers $Global:authHeader -Method Get)
        Write-Log -logFile $fileName -activity "AD100" -category "INF" -message "Exchange API Call Success"

        $cUsers = $allUsers.value

        #looping through all links

        $allUsersNextLink = $allUsers.'@odata.nextLink'
            
        while($allUsersNextLink -ne $null) {

            $allUsers = (Invoke-RestMethod -Uri $allUsersNextLink -Headers $Global:authHeader -Method Get)
            Write-Log -logFile $fileName -activity "AD100" -category "INF" -message "NextLink Call Success"

            $allUsersNextLink = $allUsers.'@odata.nextLink'

            $cUsers += $allUsers.value
        } 
            
        return $cUsers

    }
    catch {

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

        Write-Log -logFile $fileName -activity "AD100" -category "ERR" -message "FetchAzureADDetails Failed. Response content:`n$responseBody"
        Write-Log -logFile $fileName -activity "AD100" -category "ERR" -message "FetchAzureADDetails Failed. Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"


        write-host
        break
    }
}
#endregion

##################################################################

#region Get-IntuneDetail

Function Get-IntuneDetail([string]$userObjId) {

    try{

        $graphApiVersion = "Beta"
        $DCP_resource = "users/$($userObjId)/managedAppRegistrations"

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"

        (Invoke-RestMethod -Uri $uri -Headers $Global:authHeader -Method Get).value
        Write-Log -logFile $fileName -activity "ID101" -category "INF" -message "Intune API Call Success"

    }
    catch{

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

        Write-Log -logFile $fileName -activity "ID101" -category "ERR" -message "FetchIntuneDetails Failed. Response content:`n$responseBody"
        Write-Log -logFile $fileName -activity "ID101" -category "ERR" -message "FetchIntuneDetails Failed. Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"


        write-host
        break
    }
}
#endregion

##################################################################

#endregion

##################################################################

#region auth

$fileName = "autoWipe_$((get-date).tostring("yyyyMMdd")).log"

try {

    $creds = Get-StoredCredential -Target GraphNew

    $body = @{
        client_id = "5267372f-f7bc-4570-a4b2-28cb7e66646a"
        username = $creds.GetNetworkCredential().UserName
        password = $creds.GetNetworkCredential().Password
        grant_type = "password"
        resource = "https://graph.microsoft.com" 
    }
    Write-Log -logFile $fileName -activity "MT100" -category "INF" -message "Authbody Success"
}

catch {

    $ex = $_.Exception
    #Write-Host $ex.Message

    Write-Log -logFile $fileName -activity "MT100" -category "ERR" -message "Authbody Exception $($ex.Message)"
}

try {

    $tenantID = "69a5c584-5bce-450a-9ee2-4cf417193ebd"
    $DCP_resource = "/oauth2/token"

    $uri = "https://login.microsoftonline.com/$($tenantID)/$($DCP_resource)"

    $tokenResponse = Invoke-RestMethod -Uri $uri -Body $body -Method Post
    
    $Global:authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $tokenResponse.access_token
        'ExpiresOn'=$tokenResponse.Expires_On
    }

    Write-Log -logFile $fileName -activity "MT101" -category "INF" -message "AccessToken Success"
}

catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host

    Write-Log -logFile $fileName -activity "MT101" -category "ERR" -message "FetchAccessToken Failed. Response content:`n$responseBody"
    Write-Log -logFile $fileName -activity "MT101" -category "ERR" -message "FetchAccessToken Failed. Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

    break
}

#endregion

#region Main

$users = Get-AzureADDetails
Write-Log -logFile $fileName -activity "AD101" -category "INF" -message "Return Success. $($users.count) Users Found"

$today = (Get-Date).tostring('dd MMM yyyy')
Write-Log -logFile $fileName -activity "DT100" -category "INF" -message "Scope of Execution: $($today)"

foreach($user in $users) {
    
    if(($user.extension_fba7224d4c9d4ff688cab432761084a4_accountExpires) -and ($user.extension_fba7224d4c9d4ff688cab432761084a4_accountExpires -ne '9223372036854775807')) {

        $expDate = (([datetime]::FromFileTime($user.extension_fba7224d4c9d4ff688cab432761084a4_accountExpires)).AddDays(-1)).tostring('dd MMM yyyy')
        
        if($today -eq $expDate) {
            
            Write-Log -logFile $fileName -activity "DT101" -category "INF" -message "Match Found: [$($expDate)] $($user.mail)"
            Write-Log -logFile $fileName -activity "ID100" -category "INF" -message "Fetching AppRegistrations"

            $managedAppReg = Get-IntuneDetail -userObjId $user.Id
            
            if($managedAppReg) {

                $deviceTag = $ManagedAppReg.deviceTag | sort -Unique

                Write-Log -logFile $fileName -activity "ID102" -category "INF" -message "Return Success. $($managedAppReg.count) Registrations Found"
                if($deviceTag.count -eq 1) {

                    Write-Log -logFile $fileName -activity "ID103" -category "INF" -message "$($deviceTag.count) Device(s) Found"
                    Write-Log -logFile $fileName -activity "ID103" -category "INF" -message "Processing Device]::[$($deviceTag)"
                    try {

                        $uri = "https://graph.microsoft.com/beta/users/$($user.Id)/wipeManagedAppRegistrationByDeviceTag"

                        $jsonBody = @"
                        {

                            "deviceTag": "$($deviceTag)"
                        }
"@
                        Write-Log -logFile $fileName -activity "WD100" -category "INF" -message "Wiping Device]::[$($deviceTag)"
                        
                        Invoke-RestMethod -Uri $uri -Headers $Global:authHeader -Method Post -Body $jsonBody -ContentType "application/json"
                        
                        Write-Log -logFile $fileName -activity "WD100" -category "INF" -message "Wipe Request Placed"
                    }
                    catch {

                        $ex = $_.Exception
                        $errorResponse = $ex.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($errorResponse)
                        $reader.BaseStream.Position = 0
                        $reader.DiscardBufferedData()
                        $responseBody = $reader.ReadToEnd();
                        Write-Host "Response content:`n$responseBody" -f Red
                        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                        write-host

                        Write-Log -logFile $fileName -activity "WD100" -category "ERR" -message "Wipe Failed for $($deviceTag). Response content:`n$responseBody"
                        Write-Log -logFile $fileName -activity "WD100" -category "ERR" -message "Wipe Failed for $($deviceTag). Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

                        break
                    }
                }
                else {

                    Write-Log -logFile $fileName -activity "ID103" -category "INF" -message "$($deviceTag.count) Device(s) Found"
                    foreach($device in $deviceTag) {

                        Write-Log -logFile $fileName -activity "ID103" -category "INF" -message "Processing Device]::[$($device)"

                        try {

                            $uri = "https://graph.microsoft.com/beta/users/$($user.Id)/wipeManagedAppRegistrationByDeviceTag"
    
                            $jsonBody = @"
                            {
    
                                "deviceTag": "$($device)"
                            }
"@
                            Write-Log -logFile $fileName -activity "WD100" -category "INF" -message "Wiping Device]::[$($device)"
                            
                            Invoke-RestMethod -Uri $uri -Headers $Global:authHeader -Method Post -Body $jsonBody -ContentType "application/json"
                            
                            Write-Log -logFile $fileName -activity "WD100" -category "INF" -message "Wipe Request Placed for $($device)"
                        }
                        catch {
    
                            $ex = $_.Exception
                            $errorResponse = $ex.Response.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($errorResponse)
                            $reader.BaseStream.Position = 0
                            $reader.DiscardBufferedData()
                            $responseBody = $reader.ReadToEnd();
                            Write-Host "Response content:`n$responseBody" -f Red
                            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                            write-host
    
                            Write-Log -logFile $fileName -activity "WD100" -category "ERR" -message "Wipe Failed for $($device). Response content:`n$responseBody"
                            Write-Log -logFile $fileName -activity "WD100" -category "ERR" -message "Wipe Failed for $($device). Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
                            
                            break
                        }
                    }
                }
            }
            else {

                Write-Log -logFile $fileName -activity "ID102" -category "INF" -message "Return Success. $($managedAppReg.count) Registrations Found"
                Write-Log -logFile $fileName -activity "ID102" -category "INF" -message "No Action Needed"
            }
        }
        else {
            
            Write-Log -logFile $fileName -activity "DT102" -category "INF" -message "Non Matching Entry: [$($expDate)] $($user.mail)"
        }
    }
}

#endregion

##################################################################