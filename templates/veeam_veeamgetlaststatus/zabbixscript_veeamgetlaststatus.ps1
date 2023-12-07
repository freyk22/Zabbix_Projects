

#== Description ===
#veeam gest laststatus
#Script for detecting the last status of backupjobs.
#and send data to zabbix server
#script execution example: zabbixscript_veeamgetlaststatus.ps1 backupjobname
#run as administrator.


#Get script inputparameters
param([Parameter(Mandatory=$true)] [string] $VeeamJobname)

#== Settings - Zabbix Proxy ===
#ipadres of zabbix server/proxy
$zabbixserver ="172.20.1.106" 
#zabbix name of host
$zabbixhostname = "BS01"


#== Settings - Veeam ==
$VeeamHostname= "localhost" 

#== Settings - Script ==
## path to the folder where zabbixsender is located - windows
#running this script using powershell for windows, uncomment the following lines:
$zabbixsenderfolder="C:\Program Files\Zabbix Agent"
$zabbixsenderexecfile ="zabbix_sender.exe"
$scriptloglocation="C:\install\scripts\test\testzabbixscript_veeamgetlaststatus-logfile.txt"
$zabbixscripterror_itemkey = "Veeambackupstatusscript_error"



# Dont change anything, behind the following line
#=====================================================
#=====================================================
#=====================================================


#function for logging
function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
#function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) backupcheck - $logtext"; Add-Content -Path $scriptloglocation -Value "$(fncGetLogTimeStamp) msainfo - $logtext";}
function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) backupcheck - $logtext";}
Function fnczabbixsend()
{
    #function description:
    #to send data to zabbix server with zabbix sender

    Param
    (
        [Parameter(Mandatory = $true)] [string] $zabbixhostname,
        [Parameter(Mandatory = $true)] [string] $zabbixitemkey,
        [Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue_job        
    )   

    fnclog "zabbixsender - zabbixitemkey: $zabbixitemkey" 
    fnclog "zabbixsender - zabbixitemkeyvalue: $zabbixitemkeyvalue_job"
    
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k $zabbixitemkey -o "$zabbixitemkeyvalue_job" -vv
    fnclog "zabbixsender - sendresult : $zabbixsendcommand"
}

function fncscripterrorsend { 
    fnclog "Sending error"
    fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "$VeeamJobname"
    exit;
}


#Zabbixitemkey
#(zabbix itemkey is veeamjobname without any spaces and signs)
$zabbixitemkey_jobname = $VeeamJobname.Replace('-', '')
$zabbixitemkey_jobname = $zabbixitemkey_jobname.Replace('_', '')
$zabbixitemkey_jobname = $zabbixitemkey_jobname.Replace(' ', '')

fnclog "check input - VeeamJobname = $VeeamJobname"
fnclog "check input - zabbixitemkey_jobname = $zabbixitemkey_jobname"
fnclog "check input - scripterrorzabbixkeyname = $zabbixitemkey_jobname"

fnclog "check Veeam jobname - jobname = $VeeamJobname"
if (!$VeeamJobname){
    fnclog "check input Veeam jobname - error - jobname is empty."
    fnclog "check input Veeam jobname - sending error"
    fncscripterrorsend;
}else{
    fnclog "check input Veeam jobname - ok"
}


#load module
Add-PSSnapin -Name VeeamPSSnapIn
#Get-Module -Name Veeam.Backup.PowerShell
#Import-Module Veeam.Backup.PowerShell
fnclog "ps module load - VEEAM Snapin check"
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
    if (!(Add-PSSnapin -PassThru VeeamPSSnapIn)) {
        Add-PSSnapin -PassThru VeeamPSSnapIn
    }
}else{
    fnclog "ps module load - VEEAM Snapin loaded."
}

fnclog "ps module load - VEEAM Snapin check"
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
    if (!(Add-PSSnapin -PassThru VeeamPSSnapIn)) {
        # Error out if loading fails
        fnclog "ps module load - Cannot load the VEEAM Snapin."
        fncscripterrorsend;
    }
}else{
    fnclog "ps module load - VEEAM Snapin loaded."
}
  

#check window service "Veeam broker" and Veeam Backup.
fnclog "Getting job result - checking status needed service - veeam broker"
$checkservice1 = Get-Service -Name "VeeamBackupSvc" 
if ($checkservice1.Status -ne 'Running')
{
    fnclog "Getting job result - checking service veeam backup - not running"
    fnclog "Getting job result - checking service veeam backup - going to start it"
    Start-Service -Name "VeeamBackupSvc"
}else{
    fnclog "Getting job result - checking service veeam backup - running"
}


$checkservice2 = Get-Service -Name "VeeamBrokerSvc" 
if ($checkservice2.Status -ne 'Running')
{
    fnclog "Getting job result - checking service veeam broker - not running"
    fnclog "Getting job result - checking service veeam broker - going to start it"
    Start-Service -Name "VeeamBrokerSvc"
}else{
    fnclog "Getting job result - checking service veeam broker - running"
}

#check again
$checkservice1 = Get-Service -Name "VeeamBackupSvc" 
if ($checkservice1.Status -ne 'Running')
{
    fnclog "error loading service VeeamBackupSvc"
    fncscripterrorsend;
}

#check again
$checkservice2 = Get-Service -Name "VeeamBrokerSvc" 
if ($checkservice2.Status -ne 'Running'){
    fnclog "error loading service VeeamBrokerSvc"
    fncscripterrorsend;
}

#Connect to veeam server
fnclog "Veeamserver connect - connecting to veeam server"
#disconnect from all veeam servers, for clean connection
Disconnect-VBRServer
#Connect with veeam server
Connect-VBRServer -Server $VeeamHostname

#check connection
$OpenConnection = (Get-VBRServerSession).Server
if($OpenConnection -eq $VeeamHostname) {
 fnclog "Veeamserver connect - OK - Connected"
} elseif ($OpenConnection -eq $null ) {
    fnclog "Veeamserver connect - error - cannot connect"
    #disconnect from veeam server
    Disconnect-VBRServer
    fnclog "Veeamserver connect - sending script error"
    fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixitemkey_jobname" -zabbixitemkeyvalue "10"
	fncscripterrorsend;
}

#Get job and his last result.
fnclog "Getting job result - getting job details from $VeeamJobname"
$Job = Get-VBRJob -name $VeeamJobname
if($Job.LogNameMainPart -eq $VeeamJobname){
    fnclog "Getting job result - OK - job found: $VeeamJobname"
}else{
    fnclog "Getting job result - Error - job $VeeamJobname not found"
    Disconnect-VBRServer
	fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixitemkey_jobname" -zabbixitemkeyvalue "10"
    fncscripterrorsend;
}

#clean vars
$backupresultlast = ""

#Get backup results
$backupLatestRunLocal = $Job.LatestRunLocal
fnclog "Getting job result - backupLatestRunLocal $backupLatestRunLocal"
$backupresultlast = $Job.FindLastSession().Result
fnclog "Getting job result - backupresultlast $backupresultlast"

#disconnect from veeam server
fnclog "Getting job result - disconnecting from veeam server"
Disconnect-VBRServer
fnclog "Getting job result - last result from: $VeeamJobname = $backupresultlast"




fnclog "Calculating backupresult - backupresultlast = $backupresultlast"

#get last session result and compare result
#compare resultat met $Job.FindLastSession().Result
if($backupresultlast -eq "Success"){$zabbixitemkeyvalue_job="1"}
if($backupresultlast -eq "Starting"){$zabbixitemkeyvalue_job="2"} 
if($backupresultlast -eq "InProgress"){$zabbixitemkeyvalue_job="3"} 
if($backupresultlast -eq "Postprocessing"){$zabbixitemkeyvalue_job="4"} 
if($backupresultlast -eq "Pending"){$zabbixitemkeyvalue_job="5"}
if($backupresultlast -eq "idle"){$zabbixitemkeyvalue_job="6"} 
if($backupresultlast -eq "Resuming"){$zabbixitemkeyvalue_job="7"} 
if($backupresultlast -eq "Working"){$zabbixitemkeyvalue_job="8"} 
if($backupresultlast -eq "Warning"){$zabbixitemkeyvalue_job="9"}
if($backupresultlast -eq "Failed"){$zabbixitemkeyvalue_job="10"}
if($backupresultlast -eq "None"){$zabbixitemkeyvalue_job="11"} 
if($backupresultlast -eq "Pausing"){$zabbixitemkeyvalue_job="12"} 
if($backupresultlast -eq "Stopped"){$zabbixitemkeyvalue_job="13"}  
if($backupresultlast -eq "Stopping"){$zabbixitemkeyvalue_job="14"}  
if($backupresultlast -eq "WaitingRepository"){$zabbixitemkeyvalue_job="15"} 
if($backupresultlast -eq "WaitingTape"){$zabbixitemkeyvalue_job="16"}  
if($backupresultlast -eq $null){$zabbixitemkeyvalue_job="99"} 
#if($backupresultlast -eq " "){$zabbixitemkeyvalue_job="99"}
fnclog "Calculating backupresult - zabbixitemkeyvalue = $zabbixitemkeyvalue_job"

#check and calculate if the backup did happen.
$backupresultcheckdate = Get-Date
$backupresultcheckdatetodaynr = (Get-Date).Day
$backupresultcheckdateyesterday = $backupresultcheckdate.AddDays(-1)
$backupresultcheckdateyesterdaynr = $backupresultcheckdateyesterday.Day
$backupLatestRunLocalnr = $backupLatestRunLocal.Day
fnclog "Calculating backupresult - job run day = $backupLatestRunLocal = $backupLatestRunLocalnr"
fnclog "Calculating backupresult - today = $backupresultcheckdate = $backupresultcheckdatetodaynr"
fnclog "Calculating backupresult - yesterday = $backupresultcheckdateyesterday = $backupresultcheckdateyesterdaynr"
fnclog "Calculating backupresult - backupLatestRunLocalnr -eq backupresultcheckdateyesterdaynr = $backupLatestRunLocalnr -eq $backupresultcheckdateyesterdaynr"
if($backupLatestRunLocalnr -eq $backupresultcheckdateyesterdaynr){
    fnclog "Calculating backupresult - Result: backup runned yesterday"
}else{
    fnclog "Calculating backupresult - Result: backup runned not yesterday"
    $backupresultlast = "Pending"
}




#Generating zabbixsendmessage
fnclog "zabbix message - Generating zabbixsendmessage"

#format of message to send to zabbix
$msg = "$zabbixhostname $zabbixitemkey_jobname $zabbixitemkeyvalue_job"
fnclog "zabbix message - format - message to be sent: $msg"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixitemkey_jobname" -zabbixitemkeyvalue "$zabbixitemkeyvalue_job"

#send script result
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"

fnclog "zabbix sending result - done"
#end procedure
