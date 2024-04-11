################################
#== Description ===
################################
<#
    Get data from Aruba instant-on api and send it to zabbix.
    
    == example input ==
    -aiositeid "a05e8361-f098-48f0-8797-6d8083ddb470" -aiodevicename "devicename" -zabbixhostname "customer-devicename"

    The API appears to use PKCE. A detailed explination of the steps can be found here https://auth0.com/docs/flows/call-your-api-using-the-authorization-code-flow-with-pkce   
    Thanks to Luke Whitelock and Aruba
    https://mspp.io/documenting-aruba-instant-on-sites-aruba-instant-on-api/
    https://mspp.io/documenting-aruba-instant-on-sites-aruba-instant-on-api/
    source:  https://github.com/lwhitelock/HuduAutomation/blob/main/Aruba-Instant-On/Arubu-Instant-On-HTML.ps1

    
#>


##########################################
#== Script Settings - Aruba instant on ==#
##########################################

$ArubaInstantOnUser = 'username@mydowmain'
$ArubaInstantOnPass = 'mypassword'

#######################################
#== Script Settings - Zabbix server ==#
#######################################

#ipadres of zabbix server/proxy
$zabbixserver ="172.20.1.106"

#########################
#== Settings - Script ==#
#########################

$zabbixscripterror_itemkey = "aiopd_scripterror"


################################################
#== Script Settings - Zabbix agent - Windows ==#
################################################

## path to the folder where zabbixsender is located - windows
#running this script using powershell for windows, uncomment the following lines:
#$zabbixsenderfolder="C:\Program Files\Zabbix Agent"
#$zabbixsenderexecfile ="zabbix_sender.exe"
#$scriptloglocation="C:\install\scripts\testzabbixscript_arubainstantonapireader-portal-logfile.txt"

##############################################
#== Script Settings - Zabbix agent - Linux ==#
##############################################

## path to the folder where zabbixsender is located - linux
#running this script using powershell for linux, uncomment the following lines:
$zabbixsenderfolder="/usr/bin/"
$zabbixsenderexecfile="zabbix_sender"
$scriptloglocation="/var/log/zabbix-aruba-instanton-device-log.txt"


# Dont change anything, behind the following line
#=====================================================
#=====================================================
#=====================================================
#=====================================================
#=====================================================


###Standard Script functions.
function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) Aruba Instant-on portal check - $logtext";}

Function fnczabbixsend()
{   #function description: #to send data to zabbix server with zabbix sender
    Param(
            [Parameter(Mandatory = $true)] [string] $zabbixitemkey,
            [Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue
        )   
        fnclog "zabbixsender - zabbixserver $zabbixserver , zabbixhostname: $zabbixhostname"
        fnclog "zabbixsender - zabbixitemkey: $zabbixitemkey"; 
        fnclog "zabbixsender - zabbixitemkeyvalue: $zabbixitemkeyvalue";
        $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixitemkey" -o "$zabbixitemkeyvalue";
        fnclog "zabbixsender - sendresult : $zabbixsendcommand";
}

function fncscripterrorsend_script { 
    fnclog "Sending error"; 
    fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "1";
    exit
}

function fncscripterrorsend { 
    fnclog "Sending error"; 
    fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "1";
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

fnclog "Start"
fnclog "script included"

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
If ($Token.access_token -gt 0){
    fnclog "Login - got a token"
}else{
    fnclog "error - dont get a token"
    fncscripterrorsend_script;
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

# Get site id (customer id) under account
#$Sites = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
#foreach ($site in $sites.Elements) {fnclog  "Processing name - $($Site.name)"; fnclog  "Processing id - $($Site.id)";}

fnclog "===================="
fnclog "===================="
fnclog "===================="
 

function fnc_aruba_instanton_devicereader {

    #get user input
    Param
    (
        [Parameter(Mandatory = $true)] [string] $aiositeid,
        [Parameter(Mandatory = $true)] [string] $aiodevicename,
        [Parameter(Mandatory = $true)] [string] $zabbixhostname
    )
    #Get user input, save to variable
    $ArubaInstantOnsiteID = $aiositeid
    $ArubaInstantOnsiteDeviceHostname = $aiodevicename

    #Check instantonsiteid
    $ArubaInstantOnsiteIDcheck = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/landingPage" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    If ($ArubaInstantOnsiteIDcheck){
        fnclog "ArubaInstantOnsiteID check - ok got a landingpage"
    }else{
        fnclog "ArubaInstantOnsiteID check - error - idnotfound"
        fncscripterrorsend;
    }

    fnclog "Data - Getting data."

    #Get pages and save valeus to var
    $Inventory = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($ArubaInstantOnsiteID)/inventory" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json

    #Searching for data
    fnclog "Data - Searching for data"
    $Inventorydevice = $Inventory.Elements | Where-Object {$_.name -eq "$ArubaInstantOnsiteDeviceHostname"}
    
    $device_name_check = $Inventorydevice.name
    fnclog "device is '$($device_name_check)'"
    if ($device_name_check -eq '' -or $device_name_check -eq $null) {
        fnclog "error no devicename found";
        fncscripterrorsend;
    }
    
    #Display data
    fnclog "device - name: $ArubaInstantOnsiteDeviceHostname" 
    fnclog "device - name: $($Inventorydevice.name)"
    fnclog "device - model: $($Inventorydevice.model)"
    fnclog "device - status: $($Inventorydevice.status)" 
    fnclog "device - operationalState: $($Inventorydevice.operationalState)" 
    fnclog "device - uptimeInSeconds: $($Inventorydevice.uptimeInSeconds)" 
    fnclog "device - isUnderpowered: $($Inventorydevice.isUnderpowered)" 
    fnclog "device - currentFirmwareVersion: $($Inventorydevice.currentFirmwareVersion)"
    fnclog "device - currentDrtVersion: $($Inventorydevice.currentDrtVersion)"
    fnclog "device - ethernetPorts.duplex: $($Inventorydevice.ethernetPorts.duplex)"
    fnclog "device - ethernetPorts.isLinkUp: $($Inventorydevice.ethernetPorts.isLinkUp)"
    fnclog "device - ethernetPorts.isLoopDetected: $($Inventorydevice.ethernetPorts.isLoopDetected)"
    fnclog "device - ethernetPorts.isLinkFlappingDetected: $($Inventorydevice.ethernetPorts.isLinkFlappingDetected)"

    #Save data
    fnclog "Data - Save data."
    $device_name_zabbixitem = "aiopd_name"
    $device_name_zabbixvalue = $Inventorydevice.name
    $device_model_zabbixitem = "aiopd_model"
    $device_model_zabbixvalue = $Inventorydevice.model
    $device_status_zabbixitem = "aiopd_status"
    
    $device_status_zabbixvalue_ori = $Inventorydevice.status
    if($device_status_zabbixvalue_ori -eq "up"){$device_status_zabbixvalue = "1"}
    if($device_status_zabbixvalue_ori -eq "down"){$device_status_zabbixvalue = "2"}    
    if ($device_status_zabbixvalue_ori -eq '' -or $device_status_zabbixvalue_ori -eq $null) {$device_status_zabbixvalue = "3"}

    $device_operationalstate_zabbixitem = "aiopd_operationalstate"
    $device_operationalstate_zabbixvalue_ori = $Inventorydevice.operationalState
    if ($device_operationalstate_zabbixvalue_ori -eq 'active') {$device_operationalstate_zabbixvalue = "1"}
    if ($device_operationalstate_zabbixvalue_ori -eq 'down') {$device_operationalstate_zabbixvalue = "2"}
    if ($device_operationalstate_zabbixvalue_ori -eq '' -or $device_operationalstate_zabbixvalue_ori -eq $null) {$device_operationalstate_zabbixvalue = "3"}
    

    $device_uptimeinseconds_zabbixitem = "aiopd_uptimeinseconds"
    $device_uptimeinseconds_zabbixvalue = $Inventorydevice.uptimeInSeconds
    
    $device_isUnderpowered_zabbixitem = "aiopd_isunderpowered"
    $device_isUnderpowered_zabbixvalue_ori = $Inventorydevice.isUnderpowered
    if ($device_isUnderpowered_zabbixvalue_ori -eq "False"){$device_isUnderpowered_zabbixvalue = "1"}
    if ($device_isUnderpowered_zabbixvalue_ori -eq "True"){$isUnderpowered_zabbixvalue = "2"}
    if ($device_isUnderpowered_zabbixvalue_ori -eq '' -or $device_isUnderpowered_zabbixvalue_ori -eq $null) {$device_isUnderpowered_zabbixvalue = "3"}
    
    
    $device_currentfirmwareversion_zabbixitem ="aiopd_currentfirmwareversion"
    $device_currentfirmwareversion_zabbixvalue=$Inventorydevice.currentFirmwareVersion
    $device_currentdrtversion_zabbixitem ="aiopd_currentdrtversion"
    $device_currentdrtversion_zabbixvalue = $Inventorydevice.currentDrtVersion
    $device_ethernetPortsduplex_zabbixitem = "aiopd_ethernetportsduplex"
    
    $device_ethernetPortsduplex_zabbixvalue_ori = $Inventorydevice.ethernetPorts.duplex 
    if ($device_ethernetPortsduplex_zabbixvalue_ori -eq "full"){$device_ethernetPortsduplex_zabbixvalue = "1"}
    if ($device_ethernetPortsduplex_zabbixvalue_ori -ne "full"){$device_ethernetPortsduplex_zabbixvalue = "2"}
    if ($device_ethernetPortsduplex_zabbixvalue_ori -eq '' -or $device_ethernetPortsduplex_zabbixvalue_ori -eq $null) {$device_ethernetPortsduplex_zabbixvalue = "3"}


    $device_ethernetportsislinkup_zabbixitem ="aiopd_ethernetportsislinkup"    
    $device_ethernetportsislinkup_zabbixvalue_ori = $Inventorydevice.ethernetPorts.isLinkUp
    if ($device_ethernetportsislinkup_zabbixvalue_ori -eq "True"){$device_ethernetportsislinkup_zabbixvalue = "1"}
    if ($device_ethernetportsislinkup_zabbixvalue_ori -eq "False"){$device_ethernetportsislinkup_zabbixvalue = "2"}
    if ($device_ethernetportsislinkup_zabbixvalue_ori -eq '' -or $device_ethernetportsislinkup_zabbixvalue_ori -eq $null) {$device_ethernetportsislinkup_zabbixvalue = "3"}


    $device_ethernetportsisloopdetected_zabbixitem ="aiopd_ethernetportsisloopdetected"
    $device_ethernetportsisloopdetected_zabbixvalue_ori = $Inventorydevice.ethernetPorts.isLoopDetected
    if ($device_ethernetportsisloopdetected_zabbixvalue_ori -eq "False"){$device_ethernetportsisloopdetected_zabbixvalue = "1"}
    if ($device_ethernetportsisloopdetected_zabbixvalue_ori -eq "True"){$device_ethernetportsisloopdetected_zabbixvalue = "2"}
    if ($device_ethernetportsisloopdetected_zabbixvalue_ori -eq '' -or $device_ethernetportsisloopdetected_zabbixvalue_ori -eq $null) {$device_ethernetportsisloopdetected_zabbixvalue = "3"}
    

    $device_ethernetportsislinkflappingdetected_zabbixitem ="aiopd_ethernetportsislinkflappingdetected"
    $device_ethernetportsislinkflappingdetected_zabbixvalue_ori = $Inventorydevice.ethernetPorts.isLinkFlappingDetected
    if ($device_ethernetportsislinkflappingdetected_zabbixvalue_ori -eq "False"){$device_ethernetportsislinkflappingdetected_zabbixvalue = "1"}
    if ($device_ethernetportsislinkflappingdetected_zabbixvalue_ori -eq "True"){$device_ethernetportsislinkflappingdetected_zabbixvalue = "2"}
    if ($device_ethernetportsislinkflappingdetected_zabbixvalue_ori -eq '' -or $device_ethernetportsislinkflappingdetected_zabbixvalue_ori -eq $null) {$device_ethernetportsislinkflappingdetected_zabbixvalue = "3"}
    

    #Send data
    fnclog "Zabbixsender - sending data."
    fnczabbixsend -zabbixitemkey "$device_name_zabbixitem" -zabbixitemkeyvalue "$device_name_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_model_zabbixitem" -zabbixitemkeyvalue "$device_model_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_status_zabbixitem" -zabbixitemkeyvalue "$device_status_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_operationalstate_zabbixitem" -zabbixitemkeyvalue "$device_operationalstate_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_uptimeinseconds_zabbixitem" -zabbixitemkeyvalue "$device_uptimeinseconds_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_isUnderpowered_zabbixitem" -zabbixitemkeyvalue "$device_isUnderpowered_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_currentfirmwareversion_zabbixitem" -zabbixitemkeyvalue "$device_currentfirmwareversion_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_currentdrtversion_zabbixitem" -zabbixitemkeyvalue "$device_currentdrtversion_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_ethernetPortsduplex_zabbixitem" -zabbixitemkeyvalue "$device_ethernetPortsduplex_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_ethernetportsislinkup_zabbixitem" -zabbixitemkeyvalue "$device_ethernetportsislinkup_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_ethernetportsisloopdetected_zabbixitem" -zabbixitemkeyvalue "$device_ethernetportsisloopdetected_zabbixvalue"
    fnczabbixsend -zabbixitemkey "$device_ethernetportsislinkflappingdetected_zabbixitem" -zabbixitemkeyvalue "$device_ethernetportsislinkflappingdetected_zabbixvalue"



    #If script is succesful run, then send message
    fnclog "Zabbixsender - important data sended"
    fnclog "Zabbixsender - sending script ok-result"
    fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"

    fnclog "done"

    fnclog "===================="
    fnclog "===================="
    fnclog "===================="
    ############### 
    #### END ####
    ###############
    #>

}