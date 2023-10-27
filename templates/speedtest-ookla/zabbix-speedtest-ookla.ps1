<#

# == Description ==
# Measure the network download speed, using ookla speedtest.
# Output will be sended to the zabbix server.
# script made by Freek Borgerink

## Installation ##
1. import zabbix template for this script
2. install powershell for linux: 
2a. su root
2b. wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb
2c. dpkg -i packages-microsoft-prod.deb
2d. apt-get update
2e. apt-get install -y powershell
3. install ookla speedtest:
3a. su root 
3a. wget https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh
3b. bash script.deb.sh
3c. wget https://repo.zabbix.com/zabbix/5.2/debian/pool/main/z/zabbix-release/zabbix-release_5.2-1%2Bdebian10_all.deb
3d. dpkg -i zabbix-release_5.2-1+debian10_all.deb 
3c. apt-get update && apt-get install speedtest zabbix-sender
4. run as root speedtest, for the first time: speedtest 
5. accept speedtest licences
6. schedule this script in cron: */30 * * * * root /usr/bin/pwsh "/usr/local/sbin/zabbix-speedtest-ookla.ps1">/dev/null 2>&1
#>


## settings ##

##ipadres zabbix server or zabbix proxy
$zabbixserver ="172.20.1.106"
##zabbixhostname for host
$zabbixhostname = "Myfirm - Zabbix Proxy" 
$zabbixitemkey_upload="uploadspeed"
$zabbixitemkey_download="downloadspeed"


#== Settings of script ===

#Ookla speedtest settings:
$speedtestservernr=""#"5252"

#Zabbix scripterror itemkey
$zabbixscripterror_itemkey="speedtestscripterror"

#Ookla speedtest file settings - linux
$speedtestexecfolder="/usr/bin/"
$speedtestexecfile="speedtest"

#Ookla speedtest file settings - windows
#$speedtestexecfolder="c:\temp\speedtest"
#$speedtestexecfile="speedtest.exe"


#location of zabbix_sender - linux
$zabbixsenderfolder="/usr/bin/" 
$zabbixsenderexecfile="zabbix_sender" 

#location of zabbix_sender - windows
#$zabbixsenderfolder="C:\Program Files\Zabbix Agent" #"C:\Program Files\Zabbix Agent"
#$zabbixsenderexecfile ="zabbix_sender.exe" #"zabbix_sender.exe"


#dont change thing behind this line
#==================================
#==================================
#==================================
#==================================
#==================================

#functions
function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
#function fnclog($logtext){Write-Output "$(fncGetLogTimeStamp) speedtest - $logtext"; Write-Output "$(fncGetLogTimeStamp) $logtext" | Out-file $scriptloglocation -append -Force}
function fnclog($logtext){Write-Output "$(fncGetLogTimeStamp) speedtest - $logtext";}
Function fnczabbixsend()
{
    Param([Parameter(Mandatory = $true)] [string] $zabbixitemkey,[Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue)   
    #function description: to send data to zabbix server with zabbix sender
    fnclog "zabbixsender - zabbixitemkey: $zabbixitemkey"; fnclog "zabbixsender - zabbixitemkeyvalue: $zabbixitemkeyvalue";
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k $zabbixitemkey -o "$zabbixitemkeyvalue" -vv;
    fnclog "zabbixsender - sendresult : $zabbixsendcommand"
}
function fncscripterrorsend { 
    fnclog "Sending error"; 
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k "$zabbixscripterror_itemkey" -o "1" -vv;
    fnclog "zabbixsender - sendresult : $zabbixsendcommand";
    exit;
}




fnclog "Start"

#removing old ookla speedtest profile files
fnclog "preparing - removing ookla profile files"
 remove-item ~/.config/ookla -Force -Recurse -ErrorAction SilentlyContinue

fnclog "preparing - speedtest binary detection - go"
$speedtest_binary_detect  = Test-Path -Path "$speedtestexecfolder\$speedtestexecfile"
if($speedtest_binary_detect){
    fnclog "preparing - speedtest binary detection - OK - binary found"
}else{
    fnclog "preparing - speedtest binary detection - ERROR - file not found"
    fncscripterrorsend;
    exit
}



#running speedtest
fnclog "setting - ookla speedtestserver: $speedtestservernr"
fnclog "setting - command: $speedtestexecfolder$speedtestexecfile -s $speedtestservernr -f json"
fnclog "Running speedtest - running,.."

#run speedtest command and check for errors.
try
{
    $speedtest_command = .$speedtestexecfolder\$speedtestexecfile --format=json --server-id=$speedtestservernr --accept-license --accept-gdpr
}
catch
{
    #if error, display error and quit
    fnclog "Running speedtest - ERROR - error: $PSItem ";
    fncscripterrorsend;
}
#if no errror
fnclog "Running speedtest - done";

fnclog "Result - Analyzing results - go";
#convert output to json
fnclog "Result - converting results";
$speedtest_output_json = $speedtest_command | ConvertFrom-Json

fnclog "Result - checking results";
if([string]::IsNullOrEmpty($speedtest_output_json)){
    fnclog "Result - checking results - error - no speedtest ouput"; 
    fncscripterrorsend;
}else{
    fnclog "Result - checking results - ok";
}

#analysing results
fnclog "Result - Analyzing";
#calculate bytes to mb and round up
$downloadspeed_org = $speedtest_output_json.download.bytes 
$uploadspeed_org = $speedtest_output_json.upload.bytes
$downloadspeed_org = [math]::round($downloadspeed_org /1MB, 0)
$uploadspeed_org = [math]::round($uploadspeed_org /1MB, 0)

#display result
fnclog "Result - downloadspeed = '$($downloadspeed_org)'"
fnclog "Result - uploadspeed  = '$($uploadspeed_org)'"

fnclog "Result - Sending results"
fnczabbixsend -zabbixitemkey "$zabbixitemkey_upload" -zabbixitemkeyvalue "$uploadspeed_org"
fnczabbixsend -zabbixitemkey "$zabbixitemkey_download" -zabbixitemkeyvalue "$downloadspeed_org"
fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"
if($downloadspeed_org -eq 0){fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "1";}
if($uploadspeed_org -eq 0){fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "1";}



fnclog "done"
#script end
