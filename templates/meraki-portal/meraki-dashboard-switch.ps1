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
<#
Param
(
    [Parameter(Mandatory = $true)] [string] $switchname
)
#>
$switchname = "my siwthc"

################################
#== Settings - Zabbix Proxy ===#
################################

#ipadres of zabbix server/proxy
$zabbixserver = "172.30.32.131"

#Get zabbix hostname
$zabbixhostname = "myfirm-" + "$switchname"

###################################
#== Settings - Meraki#
###################################
#Generate api from dashboard.meraki.com, Organization > Settings > Dashboard API access. 

$meraki_api_url = "https://api.meraki.com/api/v1" #"https://api.meraki.com/api/v1"
$meraki_api_key = "my key" 

#########################
#== Settings - Script ==#
#########################

$zabbixscripterror_itemkey = "merakidashboard_switch_scripterror"

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


#Get Switchname
fnclog "Login - input zabbixhostname:  $zabbixhostname"
fnclog "Login - input switchname:  $switchname"

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
$networkId = (Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations/$($organizationId)/networks" -Headers $Headers).id
fnclog "Get orgdata -  organizationId is $organizationId"
fnclog "Get orgdata - networkId is $networkId"

#get devices list with all devices
fnclog "Get orgdata - Devices list"
$devices_list = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/organizations/$($organizationId)/devices/" -Headers $Headers


#get Serial
fnclog "Get orgdata Device serial for '$($switchname)'"
$deviceserial = $($devices_list | Where-Object {$_.productType -eq "switch" -and $_.name -eq "$switchname"}).serial
if ($null -eq $deviceserial){
    fnclog "Get orgdata - Device serial - Error - switch $switchname not found"
}else{
    fnclog "Get orgdata - Device serial: $deviceserial"
}

##############
##############
##############


#Get port statusses
fnclog "checking switch status - for errors and warnings"
fnclog "checking switchport - go"
#clear counters and vars
$switch_porterror_string=""
Clear-Variable switch_porterror_string
$switch_porterror_counter=0
#get switch port data
$switch_port_statuses = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/devices/$($deviceserial)/switch/ports/statuses" -Headers $Headers

foreach($switch_port_status in $switch_port_statuses){
    
    fnclog "checking switchport - checking port '$($switch_port_status.portId)'"
    fnclog "checking switchport - Status $($switch_port_status.status)"
    
    #if enabled and disconnected -> error?    

    #if warnings
    fnclog "checking switchport - search for port warning"
    if ($switch_port_status.status -eq "Connected" -and $switch_port_status.warnings -ne ''){
        fnclog "checking switchport - found warning - name: $($Switch_name) dev $($device_switch_serial) - $($switch_port_status.Portid) - warning";
        $switch_porterror_string += "warning-$($switch_port_status.Portid)"
        $switch_porterror_counter++
    }
    #if errors
    fnclog "checking switchport - search for port errors"
    if ($switch_port_status.status -eq "Connected" -and $switch_port_status.errors -ne ''){
        fnclog "checking switchport - found error - name: $($Switch_name) dev $($device_switch_serial) - $($switch_port_status.Portid) - error: $($switch_port_status.errors)"; 
        fnclog "sending errors";
        $switch_porterror_string += "error-$($switch_port_status.Portid)"
        $switch_porterror_counter++
    }
    #if disconnected and warnings
    fnclog "checking switchport - search for port errors disconnected"
    if ($switch_port_status.status -eq "Disconnected" -and $switch_port_status.warnings -ne ''){
        fnclog "checking switchport - found error - name: $($Switch_name) dev $($device_switch_serial) - $($switch_port_status.Portid) - error: $($switch_port_status.warnings)"; 
        $switch_porterror_string += "disconnectedporterror-$($switch_port_status.Portid)"
        $switch_porterror_counter++
    }

    <#
    fnclog "checking switchport - search for port duplex errors"
    if ($switch_port_status.duplex -ne 'full'){
        $switch_porterror_string += "notfullduplex-$($switch_port_status.Portid)"
        $switch_porterror_counter++
    }
    #>
}
if ($null -eq $switch_porterror_string){
    $switch_porterror_string = "null"
}

#Send port errors
fnclog "checking switchport - error counter - '$($switch_porterror_counter)'"
fnclog "checking switchport - error string  -'$($switch_porterror_string)'"

<#
fnclog "switch_port_connectionstatslist - go "    
$switch_port_connectionstatslist = Invoke-RestMethod -Method Get -Uri "$($meraki_api_url)/devices/$($deviceserial)/wireless/connectionStats" -Headers $Headers
foreach ($switch_port_connectionstat in $switch_port_connectionstatslist){
    fnclog "switch_port_statuses - id '$($switch_port_connectionstat.portId)' errors - '$($switch_port_connectionstat.errors)' warnings - '$($switch_port_connectionstat.warnings)' duplex - '$($switch_port_connectionstat.duplex)'"
}
#>

#send data to zabbix
fnczabbixsend -zabbixitemkey "switch_device_serial" -zabbixitemkeyvalue "$deviceserial"
fnczabbixsend -zabbixitemkey "switch_porterror_string" -zabbixitemkeyvalue "$switch_porterror_string"
fnczabbixsend -zabbixitemkey "switch_porterror_counter" -zabbixitemkeyvalue "$switch_porterror_counter"

<#
#If script is succesful run, then send message
fnclog "Zabbixsender - important data sended"
fnclog "Zabbixsender - sending script reulst ok"
fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"
#>

fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"
fnclog "done"

############### 
#### END ####
###############
#>