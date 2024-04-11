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



################################
#== Settings - Zabbix Proxy ===#
################################

#ipadres of zabbix server/proxy
$zabbixserver = "127.0.0.1"
#zabbix name of host
$zabbixhostname = "myfirm-MerakiPortal"

###################################
#== Settings - Meraki#
###################################
#Generate api from dashboard.meraki.com, Organization > Settings > Dashboard API access. 

$meraki_api_url = "https://api.meraki.com/api/v1" 
$meraki_api_key = "mykey"

#########################
#== Settings - Script ==#
#########################

$zabbixscripterror_itemkey = "merakidashboard_network_scripterror"

#######################################
#== Script Settings - Zabbix agent == #
#######################################

## path to the folder where zabbixsender is located - windows
#running this script using powershell for windows, uncomment the following lines:
#$zabbixsenderfolder ="C:\Program Files\Zabbix Agent"
#$zabbixsenderexecfile ="zabbix_sender.exe"
#$scriptloglocation="C:\install\scripts\testzabbixscript_meraki-logfile.txt"


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
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixitemkey" -o "$zabbixitemkeyvalue";
    fnclog "zabbixsender - sendresult : $zabbixsendcommand";
}
function fncscripterrorsend { 
    fnclog "Sending error"; 
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1";
    fnclog "zabbixsender - sendresult : $zabbixsendcommand";
    #exit;
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
fnclog "login - apikey: ******"
fnclog "login - get org id"
$organizationId = (Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations" -Headers $Headers).id
$networkId = (Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations/$($organizationId)/networks" -Headers $Headers).id
fnclog "login - organizationId is $organizationId"
fnclog "login - networkId is $networkId"

################
################
################


fnclog "================"
fnclog "health alerts - get"
$health = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)//networks/$($networkId)/health/alerts" -Headers $Headers
$health_Connectivity_list = $health | Where-Object {$_.category -eq "Connectivity"}



#Connectivity_list - unreachable device
$health_Connectivity_device_unreachable = $health_Connectivity_list | Where-Object {$_.type -eq "Unreachable device"}
$health_Connectivity_unreachable_devices_count = 0
if($health_Connectivity_device_unreachable){
    fnclog "health device - found errors"
    foreach($health_Connectivity_unreachable_device in $health_Connectivity_device_unreachable){
        $health_Connectivity_unreachable_devices_string += "$($health_Connectivity_unreachable_device.scope.devices.name)|"
        $health_Connectivity_unreachable_devices_count += 1
    }
}

if($null -eq $health_Connectivity_device_unreachable){
    fnclog "health device - no found errors"; 
    $health_Connectivity_unreachable_devices_string = "0";
    $health_Connectivity_unreachable_devices_count = "0";
}
fnclog "health alerts - health_device_unreachable_devices_string $health_Connectivity_unreachable_devices_string"
fnclog "health alerts - health_device_unreachable_count $health_Connectivity_unreachable_devices_count"

#Connectivity_list - never connected
$neverconnecteddevices_string = ""
Clear-Variable neverconnecteddevices_string
$health_Connectivity_connectednever = $health_Connectivity_list | Where-Object {$_.type -eq "Never connected to the Meraki cloud"}
$health_Connectivity_connectednever_count = $health_Connectivity_connectednever.count
fnclog "health_Connectivity_connectednever_count $health_Connectivity_connectednever_count"
$neverconnecteddevices_string = ""
Clear-Variable neverconnecteddevices_string
foreach ($neverconnecteddevice in $health_Connectivity_connectednever.scope.devices){
    fnclog "neverconnecteddevice found: $($neverconnecteddevice.name) $($neverconnecteddevice.serial) $($neverconnecteddevice.productType)"
    $neverconnecteddevices_string +="$($neverconnecteddevice.name)-$($neverconnecteddevice.serial)-$($neverconnecteddevice.productType)" 
}
if($null -eq $neverconnecteddevices_string){
    $neverconnecteddevices_string = "null"
}


fnclog "neverconnecteddevices_string $neverconnecteddevices_string"

#health - insights
fnclog "health_insights_list"
$health_insights_list_string=""
Clear-Variable health_insights_list_string

$health_insights_list = $health | Where-Object {$_.category -eq "Insights"}
foreach ($insightsobject in $health_insights_list){
    fnclog "health_insights_list - $($insightsobject.scope.devices.name) - $($insightsobject.severity) - $($insightsobject.type)  - $($insightsobject.scope.devices.productType) - $($insightsobject.scope.devices.clients.mac)"
    $health_insights_list_string +="$($insightsobject.scope.devices.name)-$($insightsobject.severity)-$($insightsobject.type)-$($insightsobject.scope.devices.productType) - $($insightsobject.scope.devices.clients.mac)|"
}
$health_insights_counter = $($health_insights_list).count

if($null -eq $health_insights_list_string){
    $health_insights_list_string="null"
}
fnclog "health_insights_counter $health_insights_counter"
fnclog "health_insights_list_string $health_insights_list_string"




##Device wireless Failed connections - assoc
fnclog "Device wireless Failed connections for 1 hour"
#$wireless_failedconnections = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/networks/$($networkId)/wireless/failedConnections?timespan=3600" -Headers $Headers
$wireless_failedconnections = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/networks/$($networkId)/wireless/failedConnections?timespan=1800" -Headers $Headers

#$wireless_failedconnections_assoc = $wireless_failedconnections | Where-Object {$_.failureStep -eq "assoc" -and $_.serial -eq "Q2KD-V46X-92WM"}
#$wireless_failedconnections_assoc_amount = 0
#foreach ($wireless_failedconnections_assoc in $wireless_failedconnections_assoc){$wireless_failedconnections_assoc_amount++;}
foreach ($wireless_failedconnections_assoc in $wireless_failedconnections){$wireless_failedconnections_assoc_amount++;}
fnclog "wireless_failedconnections_assoc_amount = $wireless_failedconnections_assoc_amount"



#Device wireless Failed connections - auth
$wireless_failedconnections_auth = $wireless_failedconnections | Where-Object {$_.failureStep -eq "auth" -and $_.serial -eq "Q2KD-V46X-92WM"}
$wireless_failedconnections_auth_amount = 0
foreach ($wireless_failedconnections_auth in $wireless_failedconnections_auth){$wireless_failedconnections_auth_amount++}
fnclog "wireless_failedconnections_auth_amount = $wireless_failedconnections_auth_amount"


fnclog "================"
fnclog "done"

fnczabbixsend -zabbixitemkey "wireless_failedconnections_assoc_amount" -zabbixitemkeyvalue "$wireless_failedconnections_assoc_amount"
fnczabbixsend -zabbixitemkey "network_health_Connectivity_unreachable_devices_count" -zabbixitemkeyvalue "$health_Connectivity_unreachable_devices_count"
fnczabbixsend -zabbixitemkey "network_health_Connectivity_unreachable_devices_string" -zabbixitemkeyvalue "$health_Connectivity_unreachable_devices_string"
fnczabbixsend -zabbixitemkey "network_health_Connectivity_connectednever_count" -zabbixitemkeyvalue "$health_Connectivity_connectednever_count"
fnczabbixsend -zabbixitemkey "network_health_Connectivity_neverconnecteddevices_string" -zabbixitemkeyvalue "$neverconnecteddevices_string"
fnczabbixsend -zabbixitemkey "network_health_insights_counter" -zabbixitemkeyvalue "$health_insights_counter"
fnczabbixsend -zabbixitemkey "network_health_insights_list_string" -zabbixitemkeyvalue "$health_insights_list_string"
fnczabbixsend -zabbixitemkey "merakidashboard_network_scripterror" -zabbixitemkeyvalue "0"

############### 
#### END ####
###############
#>
