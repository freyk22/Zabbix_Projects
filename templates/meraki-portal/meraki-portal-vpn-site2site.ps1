################################
#== Description ===
################################
<#
    Get data from meraki cloud  api and send it to zabbix.

    
#>

<#
Param(
    [Parameter(Mandatory = $true)] [string] $networkId_name,
    [Parameter(Mandatory = $true)] [string] $vpn_networkname,
    [Parameter(Mandatory = $true)] [string] $vpn_site2site_name
)   
#>

$networkId_name = "my id"
$vpn_networkname = "vpnname"
$vpn_site2site_name = "vpnnite"

################################
#== Settings - Zabbix Proxy ===#
################################

#ipadres of zabbix server/proxy
$zabbixserver = "127.0.0.1" 

#Get zabbix hostname
$zabbixhostname = "myfirm-vpns2s-dev-terwolde"

###################################
#== Settings - Meraki#
###################################
#Generate api from dashboard.meraki.com, Organization > Settings > Dashboard API access. 

$meraki_api_url = "https://api.meraki.com/api/v1"
$meraki_api_key = "mykey"

#########################
#== Settings - Script ==#
#########################

$zabbixscripterror_itemkey = "merakiportal_vpns2s_scripterror"

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


<#
    Handy sites for developer
    https://jonathan-winter.co.uk/journal/meraki-api-powershell-basics-get.html
    https://developer.cisco.com/meraki/api-latest/
    https://documentation.meraki.com/General_Administration/Other_Topics/Cisco_Meraki_Dashboard_API
    https://documenter.getpostman.com/view/897512/SzYXYfmJ
#>

###Standard Script functions.
function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) meraki-portal vpn-site2site - $logtext";}
Function fnczabbixsend()
{   #function description: #to send data to zabbix server with zabbix sender
    Param(
        [Parameter(Mandatory = $true)] [string] $zabbixhostname,
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


# Generate headers
$headers = @{
    "Content-Type" = "application/json"
    "X-Cisco-Meraki-API-Key" = $meraki_api_key
}
fnclog "login - apikey: ******"


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
fnclog "Get orgdata -  get org id"
$organizationId = (Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations" -Headers $Headers).id
$networkId = $(Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations/$($organizationId)/networks" -Headers $Headers | Where-Object {$_.name -eq "$networkId_name"}).id
if($organizationId){fnclog "organizationId = ok";}else{fnclog "organizationId = error"; fncscripterrorsend;}
if($networkId){fnclog "networkid = ok";}else{fnclog "networkid = error"; fncscripterrorsend;}
fnclog "Get orgdata -  organizationId is $organizationId"
fnclog "Get orgdata - networkId is $networkId"
fnclog "=============="

fnclog "vpn appliance - getting data..."
$vpn_appliance_list = $(Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations/$($organizationId)/appliance/vpn/statuses" -Headers $Headers | Where-Object {$_.networkName -eq "$vpn_networkname"})
if(-not $vpn_appliance_list){fnclog "vpn appliance list - error"; fncscripterrorsend;}

$vpn_appliance = $vpn_appliance_list | Where-Object {$_.networkName -eq $vpn_networkname}
if(-not $vpn_appliance){fnclog "vpn appliance - error - not found :$vpn_networkname"; fncscripterrorsend;}


$vpn_appliance_networkName = $vpn_appliance.networkName
$vpn_appliance_deviceStatus1 = $vpn_appliance.deviceStatus
if (-not $vpn_appliance_deviceStatus1 -eq "online"){$vpn_appliance_deviceStatus = "0";}else{$vpn_appliance_deviceStatus = "1";}
fnclog "vpn_appliance_deviceStatus '$($vpn_appliance_deviceStatus1)'"
fnclog "vpn_appliance_deviceStatus '$($vpn_appliance_deviceStatus)'"
fnclog "vpn appliance - netwerkname: $vpn_appliance_networkName"

fnclog "-----"

fnclog "vpnsite2site - getting data..."
$vpnsite2site_list = $vpn_appliance.merakiVpnPeers

fnclog "vpnsite2site - info for $vpn_networkname"
$vpnsite2site_object = $vpnsite2site_list | Where-Object {$_.networkName -eq $vpn_site2site_name}
if(-not $vpnsite2site_object){fnclog "vpnsite2site - error - not found: $vpn_site2site_name"; fncscripterrorsend;}
$vpnsite2site_object_networkname_value = $vpnsite2site_object.networkName
$vpnsite2site_object_reachability_value = $vpnsite2site_object.reachability


$vpnsite2site_object_reachability_value1 = $vpnsite2site_object.reachability
if (-not $vpnsite2site_object_reachability_value1 -eq "reachable"){$vpnsite2site_object_reachability_value = "0";}else{$vpnsite2site_object_reachability_value = "1";}
fnclog "vpnsite2site - reachability Status '$($vpnsite2site_object_reachability_value1)'"
fnclog "vpnsite2site - reachability Status '$($vpnsite2site_object_reachability_value)'"
fnclog "vpnsite2site - networkname: $vpnsite2site_object_networkname_value"
fnclog "=============="


#send data to zabbix
fnclog "zabbix sender - start"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "vpn_appliance_networkName" -zabbixitemkeyvalue "$vpn_appliance_networkName"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "vpn_appliance_deviceStatus" -zabbixitemkeyvalue "$vpn_appliance_deviceStatus"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "vpn_appliance_deviceStatus1" -zabbixitemkeyvalue "$vpn_appliance_deviceStatus1"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "vpnsite2site_object_networkname" -zabbixitemkeyvalue "$vpnsite2site_object_networkname_value"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "vpnsite2site_object_reachability" -zabbixitemkeyvalue "$vpnsite2site_object_reachability_value"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "vpnsite2site_object_reachability1" -zabbixitemkeyvalue "$vpnsite2site_object_reachability_value1"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"
fnclog "zabbix sender - done"

fnclog "vpn site2site done"
fnclog "done"
############### 
#### END ####
###############

#>