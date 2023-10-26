

#== Description ===
#veeam gest laststatus - by Freek Borgerink,  2021
#Script for detecting the last status of backupjobs.
#and send data to zabbix server
#script execution example: zabbixscript_veeamgetlaststatus.ps1 backupjobname
#run as administrator.


#Get script inputparameters
param([Parameter(Mandatory=$true)] [string] $VeeamJobname)
#$VeeamJobname = "External Backup Copy"


#== Settings - Zabbix Proxy ===
#ipadres of zabbix server/proxy
$zabbixserver ="192.168.10.70"
#zabbix name of host
$zabbixhostname = "customer-VEEAM01"


### settings - Veeam
$veeamserver_ip ="127.0.0.1"
$veeamserver_username="AD\myuser"
$veeamserver_password=""


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
        [Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue        
    )   

    fnclog "zabbixsender - zabbixitemkey: $zabbixitemkey" 
    fnclog "zabbixsender - zabbixitemkeyvalue: $zabbixitemkeyvalue"
    
    $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k $zabbixitemkey -o "$zabbixitemkeyvalue" -vv
    fnclog "zabbixsender - sendresult : $zabbixsendcommand"
}

function fncscripterrorsend { 
    fnclog "Sending error"
    fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "$VeeamJobname"
    exit;
}

fnclog "check Veeam jobname - jobname = $VeeamJobname"
if (!$VeeamJobname){
    fnclog "check input Veeam jobname - error - jobname is empty."
    fncscripterrorsend;
}else{
    fnclog "check input Veeam jobname - ok"
}

#Zabbixitemkey
#(zabbix itemkey is veeamjobname without any spaces and signs)
$zabbixitemkey_jobname = $VeeamJobname.Replace('-', '')
$zabbixitemkey_jobname = $zabbixitemkey_jobname.Replace('_', '')
$zabbixitemkey_jobname = $zabbixitemkey_jobname.Replace(' ', '')

fnclog "check input - VeeamJobname = $VeeamJobname"
fnclog "check input - zabbixitemkey_jobname = $zabbixitemkey_jobname"
fnclog "check input - scripterrorzabbixkeyname = $zabbixscripterror_itemkey"
fnclog "check input - VeeamJobname = $VeeamJobname"
fnclog "check input - zabbixitemkey = $zabbixitemkey"
fnclog "check input - scripterrorzabbixkeyname = $zabbixscripterror_itemkey"



#load module
Add-PSSnapin -Name VeeamPSSnapIn
<#
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
#>
  

#check window service "Veeam broker" and Veeam Backup.
fnclog "check server requirements - checking status needed service - veeam broker"
$checkservice1 = Get-Service -Name "VeeamBackupSvc" 
if ($checkservice1.Status -ne 'Running')
{
    fnclog "check server requirements - checking service veeam backup - not running"
    fnclog "check server requirements - checking service veeam backup - going to start it"
    Start-Service -Name "VeeamBackupSvc"
}else{
    fnclog "check server requirements - checking service veeam backup - running"
}


$checkservice2 = Get-Service -Name "VeeamBrokerSvc" 
if ($checkservice2.Status -ne 'Running')
{
    fnclog "check server requirements - checking service veeam broker - not running"
    fnclog "check server requirements - checking service veeam broker - going to start it"
    Start-Service -Name "VeeamBrokerSvc"
}else{
    fnclog "check server requirements - checking service veeam broker - running"
}

#check again
$checkservice1 = Get-Service -Name "VeeamBackupSvc" 
if ($checkservice1.Status -ne 'Running')
{
    fnclog "check server requirements - error loading service VeeamBackupSvc"
    fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixitemkey_jobname" -zabbixitemkeyvalue "10"
    fncscripterrorsend;
}

#check again
$checkservice2 = Get-Service -Name "VeeamBrokerSvc" 
if ($checkservice2.Status -ne 'Running'){
    fnclog "check server requirements - error loading service VeeamBrokerSvc"
    fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixitemkey_jobname" -zabbixitemkeyvalue "10"
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

$Job = ""
$Job = Get-VBRJob -Name "$VeeamJobname"
if($Job -eq $null){
    fnclog "Getting job result - The job doesn't excist"
    fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixitemkey_jobname" -zabbixitemkeyvalue "10"
    fncscripterrorsend;
}

#Get job last result
#$Job = (Get-VBRJob -Name "$VeeamJobname").FindLastSession() 
$Job = Get-VBRJob -Name "$VeeamJobname"

#clean vars
$backupresultlast = ""

#Get backup results
$sessionlast = Get-VBRBackupSession | Where {$_.jobId -eq $job.Id.Guid} | Sort EndTimeUTC -Descending | Select -First 1
fnclog "found job: $($sessionlast.JobName) - State=$($sessionlast.State), Result=$($sessionlast.Result), Start=$($sessionlast.CreationTime.DateTime), End=$($sessionlast.EndTime)"
$backupresultlast = $sessionlast.Result

$backupresultlaststate = $sessionlast.State
$backupresultlastrestult = $sessionlast.Result
if($Job.GetLastState() -eq "Stopped"){$backupresultlast = "Pending"}
fnclog "Getting job result - backupresultlastresult: $backupresultlastrestult"
fnclog "Getting job result - backupresultlaststate: $backupresultlaststate"

#disconnect from veeam server
fnclog "Getting job result - disconnecting from veeam server"
Disconnect-VBRServer
fnclog "Getting job result - last result from: $VeeamJobname = $backupresultlast"

#get last session result and compare result
#compare resultat met $Job.FindLastSession().Result
fnclog "Calculating backupresult - comparing last result with send data"
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
#if($backupresultlast -eq "None"){$zabbixitemkeyvalue_job="11"} 
if($backupresultlast -eq "None"){$zabbixitemkeyvalue_job="5"} 
if($backupresultlast -eq "Pausing"){$zabbixitemkeyvalue_job="12"} 
if($backupresultlast -eq "Stopped"){$zabbixitemkeyvalue_job="13"}  
if($backupresultlast -eq "Stopping"){$zabbixitemkeyvalue_job="14"}  
if($backupresultlast -eq "WaitingRepository"){$zabbixitemkeyvalue_job="15"} 
if($backupresultlast -eq "WaitingTape"){$zabbixitemkeyvalue_job="16"}  
if($backupresultlast -eq $null){$zabbixitemkeyvalue_job="99"} 
#if($backupresultlast -eq " "){$zabbixitemkeyvalue_job="99"}
fnclog "Calculating backupresult - comparing last result with zabbixitemkeyvalue = $backupresultlast is $zabbixitemkeyvalue_job"

<#
#check and calculate if the backup did happen.

#check and calculate if the backup did happen.
$backupresultcheckdate = Get-Date
$backupresultcheckdatetodaynr = (Get-Date).Day
$backupresultcheckdateyesterday = $backupresultcheckdate.AddDays(-1)
$backupresultcheckdateyesterdaynr = $backupresultcheckdateyesterday.Day
#$backupLatestRunLocalnr = $backupLatestRunLocal.Day
$backupLatestRunLocal = $sessionlast.EndTime
$backupLatestRunLocalnr = $sessionlast.EndTime.Day
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

fnclog "Calculating backupresult - backupresultlast = $backupresultlast"
#>



#Generating zabbixsendmessage
fnclog "zabbix message - Generating zabbixsendmessage"

#format of message to send to zabbix
$backupstatusitem= "$VeeamJobname"
$msg = "$zabbixhostname $backupstatusitem $zabbixitemkeyvalue"
fnclog "zabbix message - format - message to be sent: $msg"
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixitemkey_jobname" -zabbixitemkeyvalue "$zabbixitemkeyvalue_job"

#send script result
fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"

fnclog "zabbix sending result - done"
#end procedure
