################################
#== Description ===
################################
<#
    Get data from Aruba instant-on api and send it to zabbix.
    The API appears to use PKCE. A detailed explination of the steps can be found here https://auth0.com/docs/flows/call-your-api-using-the-authorization-code-flow-with-pkce   
    Thanks to Luke Whitelock and Aruba!
    https://mspp.io/documenting-aruba-instant-on-sites-aruba-instant-on-api/
    https://mspp.io/documenting-aruba-instant-on-sites-aruba-instant-on-api/
    source:  https://github.com/lwhitelock/HuduAutomation/blob/main/Aruba-Instant-On/Arubu-Instant-On-HTML.ps1

== example input ==
    
fnc_aruba_instanton_portalreader -aiositeid "myid" -zabbixhostname "myzabbixhostname"
#>



################################
#== Settings - Zabbix Proxy ===#
################################

#ipadres of zabbix server/proxy
$zabbixserver ="172.20.1.106"


###################################
#== Settings - Aruba instant on ==#
###################################

$ArubaInstantOnUser = 'support@myfirm.nl'
$ArubaInstantOnPass = 'mypassowrd'

#########################
#== Settings - Script ==#
#########################

## path to the folder where zabbixsender is located - windows
#running this script using powershell for windows, uncomment the following lines:
#$zabbixsenderfolder="C:\Program Files\Zabbix Agent"
#$zabbixsenderexecfile ="zabbix_sender.exe"
$zabbixscripterror_itemkey = "aiop_scripterror"
#$scriptloglocation="C:\install\scripts\testzabbixscript_arubainstantonapireader-portal-logfile.txt"

##############################################
#== Script Settings - Zabbix agent - Linux ==#
##############################################

## path to the folder where zabbixsender is located - linux
#running this script using powershell for linux, uncomment the following lines:
$zabbixsenderfolder="/usr/bin/"
$zabbixsenderexecfile="zabbix_sender"
#$scriptloglocation="/var/log/zabbix-msa-diskread-log.txt"




# Dont change anything, behind the following line
#=====================================================
#=====================================================
#=====================================================
#=====================================================
#=====================================================


###Standard Script functions.
function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
#function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) backupcheck - $logtext"; Add-Content -Path $scriptloglocation -Value "$(fncGetLogTimeStamp) msainfo - $logtext";}
function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) Aruba Instant-on portal check - $logtext";}
Function fnczabbixsend()
{   #function description: #to send data to zabbix server with zabbix sender
    Param(
        [Parameter(Mandatory = $true)] [string] $zabbixitemkey,
        [Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue
        )   
    fnclog "zabbixsender - zabbixitemkey: $zabbixitemkey"; 
    fnclog "zabbixsender - zabbixitemkeyvalue: $zabbixitemkeyvalue";
    #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixitemkey" -o "$zabbixitemkeyvalue" -vv;
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixitemkey" -o "$zabbixitemkeyvalue"
    fnclog "zabbixsender - sendresult : $zabbixsendcommand";
}
function fncscripterrorsend { 
    fnclog "Sending error"; 
    #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1" -vv;
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1"
    fnclog "zabbixsender - sendresult : $zabbixsendcommand";
    # exit;
}

function fncscripterrorsend_end { 
    fnclog "Sending error"; 
    #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1" -vv;
    #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1"
    #fnclog "zabbixsender - sendresult : $zabbixsendcommand";
    fnclog "exiting script"
    fnclog "bye"
    exit
}




function Get-URLEncode{
    param(
        [Byte[]]$Bytes
    )
    # Convert to Base 64
    $EncodedText =[Convert]::ToBase64String($Bytes)
    # Calculate Number of Padding Chars
    $Found = $false
    $EndPos = $EncodedText.Length
    do{
        if ($EncodedText[$EndPos] -ne '='){
            $found = $true
        }    
        $EndPos = $EndPos -1
    } while ($found -eq $false)

    # Trim the Padding Chars
    $Stripped = $EncodedText.Substring(0, $EndPos)
    # Add the number of padding chars to the end
    $PaddingNumber = "$Stripped$($EncodedText.Length - ($EndPos + 1))"
    # Replace Characters
    $URLEncodedString = $PaddingNumber -replace [RegEx]::Escape("+"), '-' -replace [RegEx]::Escape("/"), '_'
    return $URLEncodedString
}
        
############### 
#### Start ####
###############

# Generate the Code Verified and Code Challange used in OAUth
fnclog "Login - Generate the Code Verified and Code Challange used in OAUth"
$RandomNumberGenerator = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$Bytes = New-Object Byte[] 32
$RandomNumberGenerator.GetBytes($Bytes)
$CodeVerifier = (Get-URLEncode($Bytes)).Substring(0, 43)

$StateRandomNumberGenerator = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$StateBytes = New-Object Byte[] 32
$StateRandomNumberGenerator.GetBytes($StateBytes)
$State = (Get-URLEncode($StateBytes)).Substring(0, 43)

$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
$hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($CodeVerifier))
$CodeChallenge = (Get-URLEncode($hash)).Substring(0, 43)


#Create the form body for the initial login
fnclog "Login - Creating form body for inital login"
$LoginRequest = [ordered]@{
    username = $ArubaInstantOnUser
    password = $ArubaInstantOnPass
}


# Perform the initial authorisation
fnclog "Login - Perform the initial authorisation"
$ContentType = 'application/x-www-form-urlencoded'
$Token = (Invoke-WebRequest -Method POST -Uri "https://sso.arubainstanton.com/aio/api/v1/mfa/validate/full" -body $LoginRequest -ContentType $ContentType).content | ConvertFrom-Json
#check token
If ($Token.access_token -gt 0){
    fnclog "Login - got a token"
}else{
    fnclog "error - dont get a token"
    fncscripterrorsend_end;
}


# Dowmload the global settings and get the Client ID incase this changes.
fnclog "Login - Dowmloading the global settings" 
$OAuthSettings = (Invoke-WebRequest -Method Get -Uri "https://portal.arubainstanton.com/settings.json") | ConvertFrom-Json
$ClientID = $OAuthSettings.ssoClientIdAuthZ
fnclog "Login - Clientid: $ClientID"

# Use the initial token to perform the authorisation
fnclog "Login - Using the initial token to perform the authorisation" 
$URL = "https://sso.arubainstanton.com/as/authorization.oauth2?client_id=$ClientID&redirect_uri=https://portal.arubainstanton.com&response_type=code&scope=profile%20openid&state=$State&code_challenge_method=S256&code_challenge=$CodeChallenge&sessionToken=$($Token.access_token)"
$AuthCode = Invoke-WebRequest -Method GET -Uri $URL -MaximumRedirection 1


fnclog "Login - Extract the code returned in the redirect URL"
# Extract the code returned in the redirect URL
if ($null -ne $AuthCode.BaseResponse.ResponseUri) {
    # This is for Powershell 5
    $redirectUri = $AuthCode.BaseResponse.ResponseUri
}
elseif ($null -ne $AuthCode.BaseResponse.RequestMessage.RequestUri) {
    # This is for Powershell core
    $redirectUri = $AuthCode.BaseResponse.RequestMessage.RequestUri
}

$QueryParams = [System.Web.HttpUtility]::ParseQueryString($redirectUri.Query)
$i = 0
$ParsedQueryParams = foreach ($QueryStringObject in $QueryParams) {
    $queryObject = New-Object -TypeName psobject
    $queryObject | Add-Member -MemberType NoteProperty -Name Name -Value $QueryStringObject
    $queryObject | Add-Member -MemberType NoteProperty -Name Value -Value $QueryParams[$i]
    $queryObject
    $i++
}

$LoginCode = ($ParsedQueryParams | where-object { $_.name -eq 'code' }).value
fnclog "Login - LoginCode = $LoginCode" 

# Build the form data to request an actual token
$TokenAuth = @{
    client_id     = $ClientID
    redirect_uri  = 'https://portal.arubainstanton.com'
    code          = $LoginCode
    code_verifier = $CodeVerifier
    grant_type    = 'authorization_code' 
}

# Obtain the Bearer Token
fnclog "Login - Obtaining the Bearer Token"
$Bearer = (Invoke-WebRequest -Method POST -Uri "https://sso.arubainstanton.com/as/token.oauth2" -body $TokenAuth -ContentType $ContentType).content | ConvertFrom-Json
#fnclog "Bearer.access_token $Bearer.access_token" 

# Get the headers ready for talking to the API. Note you get 500 errors if you don't include x-ion-api-version 7 for some endpoints and don't get full data on others
$ContentType = 'application/json'
$headers = @{
    Authorization       = "Bearer $($Bearer.access_token)"
    'x-ion-api-version' = 7
}

# Get all sites under account
#$Sites = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
#foreach ($site in $sites.Elements) {fnclog  "Processing name - $($Site.name)"; fnclog  "Processing id - $($Site.id)";}

fnclog ===========
fnclog ===========
fnclog ===========

function fnc_aruba_instanton_portalreader {

    #get user input
    Param
    (
        [Parameter(Mandatory = $true)] [string] $aiositeid,
        [Parameter(Mandatory = $true)] [string] $zabbixhostname
    )

    #Get user input, save to variable
    $ArubaInstantOnsiteID = $aiositeid

    fnclog "Data - Getting data."
    fnclog "Data - Getting data for $aiositeid"
    fnclog "Data - Getting data for $zabbixhostname"

    #Check instantonsiteid
    $ArubaInstantOnsiteIDcheck = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/landingPage" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    If ($ArubaInstantOnsiteIDcheck){
        fnclog "ArubaInstantOnsiteID check - ok got a landingpage"
    }else{
        fnclog "ArubaInstantOnsiteID check - error - idnotfound"
        fncscripterrorsend;
    }

    #clear strings
    $aiop_specificerror_value = ""
    Clear-Variable -Name "aiop_specificerror_value"

    #Get pages and save valeus to var
    $LandingPage = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/landingPage" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$administration = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/administration" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$timezone = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/timezone" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $maintenance = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/maintenance" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$Alerts = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/alerts" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $AlertsSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/alertsSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$applicationCategoryUsage = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/applicationCategoryUsage" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json 
    $Inventory = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/inventory" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$ClientSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/clientSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$WiredClientSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/wiredClientSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$WiredNetworks = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/wiredNetworks" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$networksSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/networksSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$Summary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$capabilities = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/capabilities" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$radiusNasSettings = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/radiusNasSettings" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$reservedIpSubnets = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/reservedIpSubnets" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$defaultWiredNetwork = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/defaultWiredNetwork" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$guestPortalSettings = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/guestPortalSettings" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    #$ClientBlacklist = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/clientBlacklist" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json 
    #$applicationCategoryUsageConfiguration = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/applicationCategoryUsageConfiguration" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json


    #get specific errors for inventory
    foreach ($inventory_object in $Inventory.Elements){
        # if defice is status up but operational down.
        if ($inventory_object.operationalState -eq "down"){
                fnclog "error - name $($inventory_object.Name), status $($inventory_object.status) operationalstate $($inventory_object.operationalState)"
                $aiop_specificerror_value += "inventory_name-$($inventory_object.Name)_status-$($inventory_object.status)_operationalstate-$($inventory_object.operationalState)|"
            }else{
                #fnclog "ok - name $($inventory_object.Name), status $($inventory_object.status) operationalstate $($inventory_object.operationalState)"
        }
    }

    fnclog "Data - Save data."
    $landingpage_name_zabbixitem = "aiop_LandingPage_siteName"
    $landingpage_name_zabbixvalue = $LandingPage.siteName
    $landingpage_health_zabbixitem = "aiop_LandingPage_health"
    $landingpage_health_zabbixvalue = $LandingPage.health
    $landingpage_healthreason_zabbixitem = "aiop_LandingPage_healthReason"
    $landingpage_healthreason_zabbixvalue = $LandingPage.healthReason
    $landingpage_activeAlertsCount_zabbixitem =  "aiop_LandingPage_activeAlertsCount"
    $landingpage_activeAlertsCount_zabbixvalue =  $LandingPage.activeAlertsCount
    $maintenance_State_zabbixitem = "aiop_maintenance_state"
    $maintenance_State_zabbixvalue = $maintenance.state
    $maintenance_totalDeviceToUpdate_zabbixitem =  "aiop_maintenance_totalDeviceToUpdate"
    $maintenance_totalDeviceToUpdate_zabbixvalue =  $maintenance.totalDeviceToUpdate
    $Alertsummary_activeInfoAlertsCount_zabbixitem = "aiop_AlertsSummary_activeInfoAlertsCount"
    $Alertsummary_activeInfoAlertsCount_zabbixvalue = $AlertsSummary.activeInfoAlertsCount
    $Alertsummary_activeMinorAlertsCount_zabbixitem = "aiop_AlertsSummary_activeMinorAlertsCount"
    $Alertsummary_activeMinorAlertsCount_zabbixvalue = $AlertsSummary.activeMinorAlertsCount
    $Alertsummary_activeMajorAlertsCount_zabbixitem = "aiop_AlertsSummary_activeMajorAlertsCount"
    $Alertsummary_activeMajorAlertsCount_zabbixvalue = $AlertsSummary.activeMajorAlertsCount


    fnclog "aiop_specificerror_value '$($aiop_specificerror_value)'"
    if ($null -eq $aiop_specificerror_value){
        fnclog "aiop_specificerror_value is empty"
        fnclog "aiop_specificerror_value save null string"
        $aiop_specificerror_value = "null"
        fnclog "aiop_specificerror_value = $aiop_specificerror_value"
    }else{
        fnclog "aiop_specificerror_value is not empty"
        fnclog "aiop_specificerror_value = $aiop_specificerror_value"
        }


    fnclog "Zabbixsender - sending data."

    fnczabbixsend -zabbixitemkey "$landingpage_name_zabbixitem" -zabbixitemkeyvalue "$landingpage_name_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$landingpage_health_zabbixitem" -zabbixitemkeyvalue "$landingpage_health_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$landingpage_healthreason_zabbixitem" -zabbixitemkeyvalue "$landingpage_healthreason_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$landingpage_activeAlertsCount_zabbixitem" -zabbixitemkeyvalue "$landingpage_activeAlertsCount_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$maintenance_State_zabbixitem" -zabbixitemkeyvalue "$maintenance_State_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$maintenance_totalDeviceToUpdate_zabbixitem" -zabbixitemkeyvalue "$maintenance_totalDeviceToUpdate_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$Alertsummary_activeInfoAlertsCount_zabbixitem" -zabbixitemkeyvalue "$Alertsummary_activeInfoAlertsCount_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$Alertsummary_activeMinorAlertsCount_zabbixitem" -zabbixitemkeyvalue "$Alertsummary_activeMinorAlertsCount_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$Alertsummary_activeMajorAlertsCount_zabbixitem" -zabbixitemkeyvalue "$Alertsummary_activeMajorAlertsCount_zabbixvalue"

    fnczabbixsend -zabbixitemkey "aiop_specificerror_value" -zabbixitemkeyvalue "$aiop_specificerror_value"

    #If script is succesful run, then send message
    fnclog "Zabbixsender - important data sended"
    fnclog "Zabbixsender - sending script reulst ok"
    fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"
    fnclog "done"
    fnclog ===========
    fnclog ===========
    fnclog ===========

    ############### 
    #### END ####
    ###############
    
}
#end function