################################
#== Description ===
################################
<#
    Get data from meraki cloud  api and send it to zabbix.

    Handy sites
    https://developer.cisco.com/meraki/api-latest/
    https://jonathan-winter.co.uk/journal/meraki-api-powershell-basics-get.html
    https://documentation.meraki.com/General_Administration/Other_Topics/Cisco_Meraki_Dashboard_API
    https://documenter.getpostman.com/view/897512/SzYXYfmJ
#>



################################
#== Settings - Zabbix Proxy ===#
################################

#ipadres of zabbix server/proxy
$zabbixserver = "172.20.1.106"
#zabbix name of host
$zabbixhostname = "myfirm-Meraki-Portal-test" # 

###################################
#== Settings - Meraki#
###################################
#Generate api from dashboard.meraki.com, Organization > Settings > Dashboard API access. 

$meraki_api_url = "https://api.meraki.com/api/v1" #"https://api.meraki.com/api/v1"
$meraki_api_key = "my api key" 

#########################
#== Settings - Script ==#
#########################

$zabbixscripterror_itemkey = "merakidashboard_portal_scripterror"

#######################################
#== Script Settings - Zabbix agent == #
#######################################

## path to the folder where zabbixsender is located - windows
#running this script using powershell for windows, uncomment the following lines:
$zabbixsenderfolder ="C:\Program Files\Zabbix Agent"
$zabbixsenderexecfile ="zabbix_sender.exe"

## path to the folder where zabbixsender is located - linux
#running this script using powershell for linux, uncomment the following lines:
#$zabbixsenderfolder="/usr/bin/"
#$zabbixsenderexecfile="zabbix_sender"




# Dont change anything, behind the following line
#=====================================================
#=====================================================
#=====================================================
#=====================================================
#=====================================================


###Standard Script functions.
function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) Meraki portal - $logtext";}
Function fnczabbixsend()
{   #function description: #to send data to zabbix server with zabbix sender
    Param(
        #[Parameter(Mandatory = $true)] [string] $zabbixhostname,
        [Parameter(Mandatory = $true)] [string] $zabbixitemkey,
        [Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue
        )   
    fnclog "zabbixsender - itemkey: '$($zabbixitemkey)' itemkeyvalue: '$($zabbixitemkeyvalue)'";
    #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixitemkey" -o "$zabbixitemkeyvalue" -vv;
    fnclog "zabbixsender - sendresult: $($zabbixsendcommand)";
}

function fncscripterrorsend { 
    fnclog "zabbixsender - Sending error"; 
    #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1" -vv;
    fnclog "zabbixsender - sendresult: : $zabbixsendcommand";
    exit;
}


# Generate headers
$headers = @{
    "Content-Type" = "application/json"
    "X-Cisco-Meraki-API-Key" = $meraki_api_key
}

function fncapi_query() {
    #function to get send and get querry data 
    Param([Parameter(Mandatory=$true)][String]$apiquery); 
    $apiquery_input = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)$($apiquery)" -Headers $Headers; 
    return $apiquery_input;
}

#Login - check api login 
fnclog "Login - check api login - go"

try {
    fncapi_query "/organizations" | Out-Null
} catch {
    fnclog "Login - check api login - error found"
    fnclog "Login - check api login - error StatusCode: $($_.Exception.Response.StatusCode.value__)" 
    fnclog "Login - check api login - error StatusCode: $($_.Exception.Response.StatusDescription)"   
    fncscripterrorsend;
}
fnclog "Login - check api login - ok"

#Get organization id
fnclog "login - get org id"
$organizationId = (fncapi_query "/organizations").id
$networkId = (fncapi_query "/organizations/$($organizationId)/networks").id
fnclog "login - organizationId is $organizationId"
fnclog "login - networkId is $networkId"
fnclog "================"


################
################
################
      
## firmware upgrades ##

<#
fnclog "firmware upgrades"
$firmware_upgrades_list = fncapi_query "/networks/$($networkId)/firmwareUpgrades"
$firmware_upgrades_available_switch_count = $($firmware_upgrades_list.products.switch.availableVersions | Where-Object {$_.releaseType -eq "stable"}  | measure).count
fnclog "firmware_upgrades_available_switch_count $firmware_upgrades_available_switch_count"
$firmware_upgrades_available_wireless_count = $($firmware_upgrades_list.products.wireless.availableVersions | Where-Object {$_.releaseType -eq "stable"} | measure).count
fnclog "firmware_upgrades_available_wireless_count $firmware_upgrades_available_wireless_count"
fnczabbixsend -zabbixitemkey "firmware_upgrades_available_switch_count"-zabbixitemkeyvalue "$firmware_upgrades_available_switch_count"
fnczabbixsend -zabbixitemkey "firmware_upgrades_available_wireless_count" -zabbixitemkeyvalue "$firmware_upgrades_available_wireless_count"
#>

#Gettings upgrades for switch
fnclog "firmware upgrades - getting data for switch"
$firmware_upgrades_list = fncapi_query "/networks/$($networkId)/firmwareUpgrades"
$firmware_devices_switch_version_available = $($firmware_upgrades_list.products.switch.availableVersions | Where-Object {$_.releaseType -eq "stable"}).firmware
$firmware_devices_switch_version_installed = $(fncapi_query "/networks/$($networkId)/devices" | Where-Object {$_.firmware -like "switch-*"}).firmware[0]

fnclog "firmware upgrades - switch - version installed: $firmware_devices_switch_version_installed"
fnclog "firmware upgrades - switch - version available: $firmware_devices_switch_version_available"

if($firmware_devices_switch_version_installed){
    if($firmware_devices_switch_version_installed -ne $firmware_devices_switch_version_available){
        $firmware_upgrades_available_switch_count = "1"; 
        fnclog "firmware upgrades - switch - new firmware available - yes";
    }else{
        $firmware_upgrades_available_switch_count = "0"; 
        fnclog "firmware upgrades - switch - new firmware available - no";
    }
}else{
    $firmware_upgrades_available_switch_count = "0"; 
    fnclog "firmware upgrades - switch - new firmware available - no";
}


#Gettings upgrades for wireless
fnclog "firmware upgrades - getting data for wireless"
$firmware_devices_wireless_version_available = $($firmware_upgrades_list.products.wireless.availableVersions | Where-Object {$_.releaseType -eq "stable"}).firmware
$firmware_devices_wireless_version_installed = $(fncapi_query "/networks/$($networkId)/devices" | Where-Object {$_.firmware -like "wireless-*"}).firmware[0]
fnclog "firmware upgrades - wireless - version installed: $firmware_devices_wireless_version_installed"
fnclog "firmware upgrades - wireless - version available: $firmware_devices_wireless_version_available"
if($firmware_devices_wireless_version_installed){
    if($firmware_devices_wireless_version_installed -ne $firmware_devices_wireless_version_available){
        $firmware_upgrades_available_wireless_count  = "1"; 
        fnclog "firmware upgrades - wireless - new firmware available: yes";
    }else{
        $firmware_upgrades_available_wireless_count  = "0";   
        fnclog "firmware upgrades - wireless - new firmware available: no"
    }
}else{
    $firmware_upgrades_available_wireless_count  = "0";   
    fnclog "firmware upgrades - wireless - new firmware available: no"
}
fnczabbixsend -zabbixitemkey "firmware_upgrades_available_switch_count"-zabbixitemkeyvalue "$firmware_upgrades_available_switch_count"
fnczabbixsend -zabbixitemkey "firmware_upgrades_available_wireless_count" -zabbixitemkeyvalue "$firmware_upgrades_available_wireless_count"


#** License info **
fnclog "license info" 

#get data
$license_expirationDate = $(fncapi_query "/organizations/$($organizationId)/licenses/overview").expirationDate
$license_status_original = $(fncapi_query "/organizations/$($organizationId)/licenses/overview").status
#convert $license_expirationDate to numbers
$license_expirationDate_array = $license_expirationDate.Split(" ")
$license_expirationDate_array_month_letter = $license_expirationDate_array[0]
$license_expirationDate_array_daynr = $license_expirationDate_array[1].split(',')[0]
$license_expirationDate_array_year = $license_expirationDate_array[2]
if ($license_expirationDate_array_month_letter -eq "Jan"){$license_expirationDate_array_monthnr = "01"}
if ($license_expirationDate_array_month_letter -eq "Feb"){$license_expirationDate_array_monthnr = "02"}
if ($license_expirationDate_array_month_letter -eq "Mar"){$license_expirationDate_array_monthnr = "03"}
if ($license_expirationDate_array_month_letter -eq "Apr"){$license_expirationDate_array_monthnr = "04"}
if ($license_expirationDate_array_month_letter -eq "May"){$license_expirationDate_array_monthnr = "05"}
if ($license_expirationDate_array_month_letter -eq "Jun"){$license_expirationDate_array_monthnr = "06"}
if ($license_expirationDate_array_month_letter -eq "Jul"){$license_expirationDate_array_monthnr = "07"}
if ($license_expirationDate_array_month_letter -eq "Aug"){$license_expirationDate_array_monthnr = "08"}
if ($license_expirationDate_array_month_letter -eq "Sep"){$license_expirationDate_array_monthnr = "09"}
if ($license_expirationDate_array_month_letter -eq "Oct"){$license_expirationDate_array_monthnr = "10"}
if ($license_expirationDate_array_month_letter -eq "Nov"){$license_expirationDate_array_monthnr = "11"}
if ($license_expirationDate_array_month_letter -eq "Dec"){$license_expirationDate_array_monthnr = "12"}
$license_expirationDate_numeric_stringcalculate = "$($license_expirationDate_array_monthnr)/$($license_expirationDate_array_daynr)/$($license_expirationDate_array_year)" 
$license_expirationDate_numeric = [datetime]::ParseExact($license_expirationDate_numeric_stringcalculate, 'MM/dd/yyyy', $null)
#calculate if expired before 31 days
if ((get-date) -gt (get-date $license_expirationDate_numeric.AddDays(-31))){$license_expirationDate_warning = "4";}else{$license_expirationDate_warning = "3";}
#data display
fnclog "license_expirationDate $license_expirationDate"
fnclog "license_status $license_status_original"
fnclog "license_status warning $license_expirationDate_warning"
#data send
fnczabbixsend -zabbixitemkey "license_expirationDate" -zabbixitemkeyvalue "$license_expirationDate"
fnczabbixsend -zabbixitemkey "license_status_original" -zabbixitemkeyvalue "$license_status_original"
fnczabbixsend -zabbixitemkey "license_status_warning" -zabbixitemkeyvalue "$license_expirationDate_warning"



#todo: -Switch > switches (offline alterting online dormant)
fnclog "switch info"
$devices_availabilities = fncapi_query "/organizations/$($organizationId)/devices/availabilities";
$switchdevices_availability_online = $devices_availabilities | Where-Object {$_.productType -eq "switch" -and $_.status -eq "online"}
$switchdevices_availability_offline = $devices_availabilities | Where-Object {$_.productType -eq "switch" -and $_.status -eq "offline" }
$switchdevices_availability_offline_hostnames = ""
$switchdevices_availability_offline_hostnames += $switchdevices_availability_offline.name
fnclog "switch - online $($switchdevices_availability_online.count)"
fnclog "switch - offline $($switchdevices_availability_offline.count)"
fnclog "switch - offline names: $($switchdevices_availability_offline.count)-$($switchdevices_availability_offline_names)"
fnczabbixsend -zabbixitemkey "switchdevices_availability_online_count" -zabbixitemkeyvalue "$($switchdevices_availability_online.count)"
fnczabbixsend -zabbixitemkey "switchdevices_availability_offline_count" -zabbixitemkeyvalue "$($switchdevices_availability_offline.count)"
fnczabbixsend -zabbixitemkey "switchdevices_availability_offline_hostnames" -zabbixitemkeyvalue "$($switchdevices_availability_offline.count)-$($switchdevices_availability_offline_hostnames)"




#todo: -Wireless > overview > connection health, Performance Heath
fnclog "devices_availabilities:"
$devices_availabilities = fncapi_query "/organizations/$($organizationId)/devices/availabilities"; 
$wirelessdevices_availability_online = $devices_availabilities | Where-Object {$_.productType -eq "wireless" -and $_.status -eq "online"}
$wirelessdevices_availability_offline = $devices_availabilities | Where-Object {$_.productType -eq "wireless" -and $_.status -eq "offline"}
$wirelessdevices_availability_offline_hostnames = "$($wirelessdevices_availability_offline.count)"
$wirelessdevices_availability_offline_hostnames += "$($wirelessdevices_availability_offline.name)"
fnclog "wireless - online $($wirelessdevices_availability_online.count)"
fnclog "wireless - offline $($wirelessdevices_availability_offline.count)"
fnclog "wireless - offline names: $($wirelessdevices_availability_offline.count)-$($wirelessdevices_availability_offline_names)"
fnczabbixsend -zabbixitemkey "wirelessdevices_availability_online_count" -zabbixitemkeyvalue "$($wirelessdevices_availability_online.count)"
fnczabbixsend -zabbixitemkey "wirelessdevices_availability_offline_count" -zabbixitemkeyvalue "$($wirelessdevices_availability_offline.count)"
fnczabbixsend -zabbixitemkey "wirelessdevices_availability_offline_hostnames" -zabbixitemkeyvalue "$($wirelessdevices_availability_offline_hostnames)"


#device health alerts
fnclog "Device health alerts:"
fnclog "Device health alerts:"
$devicehealthalerts_list = fncapi_query "/networks/$($networkId)/health/alerts"
$devicehealthalerts_list_warning = $devicehealthalerts_list | Where-Object {$_.severity -eq "warning"}
$devicehealthalerts_list_empty = $devicehealthalerts_list | Where-Object {$_.severity -eq " "}
$devicehealthalerts_list_warning_string =""
$devicehealthalerts_list_warning_string ="$($devicehealthalerts_list.count)"
$devicehealthalerts_list_warning_string +="$($devicehealthalerts_list_warning.category)-$($devicehealthalerts_list_warning.severity)-$($devicehealthalerts_list_warning.type)-$($devicehealthalerts_list_warning.scope.devices.name)"
fnclog "devicehealthalerts_count $($devicehealthalerts_list.count)"
fnclog "devicehealthalerts_list_warning $($devicehealthalerts_list_warning.count)"
fnclog "devicehealthalerts_list_empty $($devicehealthalerts_list_empty.count)"
fnclog "accespoint_healthalerts_count $($devicehealthalerts_list.count)"
fnclog "accespoint_healthalerts_string $($devicehealthalerts_list_warning_string)"
fnczabbixsend -zabbixitemkey "device_healthalerts_count" -zabbixitemkeyvalue "$($devicehealthalerts_list.count)"
fnczabbixsend -zabbixitemkey "device_healthalerts_list_warning_count" -zabbixitemkeyvalue "$($devicehealthalerts_list_warning.count)"
fnczabbixsend -zabbixitemkey "device_healthalerts_list_empty_count" -zabbixitemkeyvalue "$($devicehealthalerts_list_empty.count)"
fnczabbixsend -zabbixitemkey "accespoint_healthalerts_count" -zabbixitemkeyvalue "$($devicehealthalerts_list.count)"
fnczabbixsend -zabbixitemkey "accespoint_healthalerts_string" -zabbixitemkeyvalue "$($devicehealthalerts_list_warning_string)"


#sending data.
<#
fnczabbixsend -zabbixitemkey "network_health_Connectivity_unreachable_devices_count" -zabbixitemkeyvalue "$health_Connectivity_unreachable_devices_count"
fnczabbixsend -zabbixitemkey "network_health_Connectivity_unreachable_devices_string" -zabbixitemkeyvalue "$health_Connectivity_unreachable_devices_string"
fnczabbixsend -zabbixitemkey "network_health_Connectivity_connectednever_count" -zabbixitemkeyvalue "$health_Connectivity_connectednever_count"
fnczabbixsend -zabbixitemkey "network_health_Connectivity_neverconnecteddevices_string" -zabbixitemkeyvalue "$neverconnecteddevices_string"
fnczabbixsend -zabbixitemkey "network_health_insights_counter" -zabbixitemkeyvalue "$health_insights_counter"
fnczabbixsend -zabbixitemkey "network_health_insights_list_string" -zabbixitemkeyvalue "$health_insights_list_string"
#>

fnclog "================"
fnclog "searching done"


fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"

fnclog "done"
############# 
#### END ####
#############