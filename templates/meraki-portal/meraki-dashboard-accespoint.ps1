################################
#== Description ===
################################
<#
    Get data from meraki cloud  api and send it to zabbix.

    Handy sites
    https://jonathan-winter.co.uk/journal/meraki-api-powershell-basics-get.html
    https://developer.cisco.com/meraki/api-latest/
    https://documentation.meraki.com/General_Administration/Other_Topics/Cisco_Meraki_Dashboard_API
    https://documenter.getpostman.com/view/897512/SzYXYfmJ
#>


#get user input
Param
(
    [Parameter(Mandatory = $false)][string] $devicename
)

#$devicename = "1ap1" #"bap2"

################################
#== Settings - Zabbix Proxy ===#
################################

#ipadres of zabbix server/proxy
$zabbixserver = "127.0.0.1"
#zabbix name of host
$zabbixhostname = "myfirm-" + "$devicename" #

###################################
#== Settings - Meraki#
###################################
#Generate api from dashboard.meraki.com, Organization > Settings > Dashboard API access. 

$meraki_api_url = "https://api.meraki.com/api/v1" #"https://api.meraki.com/api/v1"
$meraki_api_key = "myapikey" 

#########################
#== Settings - Script ==#
#########################

$zabbixscripterror_itemkey = "merakidashboard_accespoint_scripterror"

#######################################
#== Script Settings - Zabbix agent == #
#######################################

## path to the folder where zabbixsender is located - windows
#running this script using powershell for windows, uncomment the following lines:
$zabbixsenderfolder ="C:\Program Files\Zabbix Agent"
$zabbixsenderexecfile ="zabbix_sender.exe"
#$scriptloglocation="C:\install\scripts\testzabbixscript_meraki-logfile.txt"


## path to the folder where zabbixsender is located - linux
#running this script using powershell for linux, uncomment the following lines:
#$zabbixsenderfolder="/usr/bin/"
#$zabbixsenderexecfile="zabbix_sender"
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
function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) meraki portal - $logtext";}
Function fnczabbixsend()
{   #function description: #to send data to zabbix server with zabbix sender
    Param(
        #[Parameter(Mandatory = $true)] [string] $zabbixhostname,
        [Parameter(Mandatory = $true)] [string] $zabbixitemkey,
        [Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue
        )   
    fnclog "zabbixsender - zabbixitemkey: $zabbixitemkey"; 
    fnclog "zabbixsender - zabbixitemkeyvalue: $zabbixitemkeyvalue";
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixitemkey" -o "$zabbixitemkeyvalue" -vv;
    fnclog "zabbixsender - sendresult : $zabbixsendcommand";
}
function fncscripterrorsend { 
    fnclog "Sending error"; 
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1" -vv;
    fnclog "zabbixsender - sendresult : $zabbixsendcommand";
    exit;
}


if ($null -eq $devicename){
    fnclog "input - error - devicename not given"
    fncscripterrorsend;
}else{
    fnclog "input - ok"
}


# Generate headers
$APIKey = "$meraki_api_key"
$headers = @{
    "Content-Type" = "application/json"
    "X-Cisco-Meraki-API-Key" = $APIKey
}


#Login - check api login 
fnclog "Login - check api login - go"

try {
    Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations" -Headers $Headers | Out-Null
} catch {
    fnclog "Login - check api login - error found"
    fnclog "Login - check api login - error StatusCode: $($_.Exception.Response.StatusCode.value__)" 
    fnclog "Login - check api login - error StatusCode: $($_.Exception.Response.StatusDescription)"   
    fncscripterrorsend;
}
fnclog "Login - check api login - ok"



#Get organization id
fnclog "login - get org id"
$organizationId = (Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations" -Headers $Headers).id
$networkId = (Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations/$($organizationId)/networks" -Headers $Headers).id
fnclog "login - organizationId is $organizationId"
fnclog "login - networkId is $networkId"


#get devices list with all devices
$devices_list = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations/$($organizationId)/devices/" -Headers $Headers


#get Serial
fnclog "Get orgdata Device serial for '$($devicename)'"
$deviceserial = $($devices_list | Where-Object {$_.productType -eq "wireless" -and $_.name -eq "$devicename"}).serial
if ($null -eq $deviceserial){
    fnclog "Get orgdata - Device serial - Error - Accespoint $devicename not found"
    fncscripterrorsend;
}else{
    fnclog "Get orgdata - Device serial: $deviceserial"
}
#================
#================
#================

##Device wireless status
fnclog "Device wireless status"
$devices_wireless_status = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/devices/$($deviceserial)/wireless/status" -Headers $Headers
$devices_wireless_hotspots_count = $($devices_wireless_status.basicServiceSets).count
fnclog "devices_wireless_hotspots_count $devices_wireless_hotspots_count"


#device health alerts
fnclog "Device health alerts:"
$devicehealthalertslist = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/networks/$($networkId)/health/alerts" -Headers $Headers
$devicehealthalerts = $devicehealthalertslist | Where-Object {$_.category -eq "Connectivity" -and $_.scope.devices.name -eq "$devicename"} 
#$devicehealthalerts = $devicehealthalertslist | Where-Object {$_.category -eq "Connectivity" -and $_.scope.devices.name -eq "c1ap3"} 
$devicehealthalerts_count = $devicehealthalerts.count
$devicehealthalerts_string = ""
Clear-Variable devicehealthalerts_string
foreach ($devicehealthalert in $devicehealthalerts){
    fnclog "alert found: $($devicehealthalert.scope.devices.name) severity: '$($devicehealthalert.severity)' type: '$($devicehealthalert.type)'"
    $devicehealthalerts_string += "$($devicehealthalert.scope.devices.name)-$($devicehealthalert.severity)-$($devicehealthalert.type)|"
}
fnclog "devicehealthalerts_count = $devicehealthalerts_count"
fnclog "devicehealthalerts_string = $devicehealthalerts_string"
if($null -eq $devicehealthalerts_string ){
    fnclog "devicehealthalerts_string is empty"
    $devicehealthalerts_string = "null"
}

#Device wireless connection stats
fnclog "Device wireless connection stats - for hour"
$devices_wireless_connectionstats = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/devices/$($deviceserial)/wireless/connectionStats?timespan=3600" -Headers $Headers
$devices_wireless_connectionstats_success = $devices_wireless_connectionstats.connectionStats.success
fnclog "Device wireless connection stats  for hour - success $devices_wireless_connectionstats_success"

#send data to zabbix
fnczabbixsend -zabbixitemkey "accespoint_device_serial" -zabbixitemkeyvalue "$deviceserial"
fnczabbixsend -zabbixitemkey "accespoint_hotspots_count" -zabbixitemkeyvalue "$devices_wireless_hotspots_count"
fnczabbixsend -zabbixitemkey "accespoint_healthalerts_count" -zabbixitemkeyvalue "$devicehealthalerts_count"
fnczabbixsend -zabbixitemkey "accespoint_healthalerts_string" -zabbixitemkeyvalue "$devicehealthalerts_string"
fnczabbixsend -zabbixitemkey "accespoint_connectionstats_success" -zabbixitemkeyvalue "$devices_wireless_connectionstats_success"



fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"
fnclog "done"

############### 
#### END ####
###############
#>