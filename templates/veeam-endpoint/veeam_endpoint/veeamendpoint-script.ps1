<#
== Description ===
Script to read messages from veeam endpoint in windows eventviewer
#>


<#
Param(
    [Parameter(Mandatory = $true)] [string] $zabbixhostname,
    [Parameter(Mandatory = $true)] [string] $backupjob
)
#>

#== script settings ==
$backupjob = "ESX01" #DBASE01-Daily-Full
$zabbixhostname = "Customer-veeamjob-something"
$zabbixscripterror_itemkey="veeamendpoint_errorscript"


#== Settings - Zabbix Proxy ===

#ipadres of zabbix server/proxy
$zabbixserver ="192.168.228.106"

##running this script using powershell for windows
##folderpath of zabbix agent
$zabbixsenderfolder="C:\Program Files\Zabbix Agent"
##filename of zabbix agent
$zabbixsenderexecfile ="zabbix_sender.exe"

#running this script using powershell for linux, uncomment the following lines:
##folderpath of zabbix agent
#$zabbixsenderfolder="/usr/bin/" 
##filename of zabbix agent
#$zabbixsenderexecfile="zabbix_sender"

# Dont change anything, behind the following line
#=====================================================
#=====================================================
#=====================================================
#=====================================================
#=====================================================



###Standard Script functions.
function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
#function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) backupcheck - $logtext"; Add-Content -Path $scriptloglocation -Value "$(fncGetLogTimeStamp) msainfo - $logtext";}
function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) Veeam Endpoint Checker - $logtext";}
Function fnczabbixsend()
{
    #function description:
    #to send data to zabbix server with zabbix sender

    Param
    (
        [Parameter(Mandatory = $true)] [string] $zabbixitemkey,
        [Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue        
    )   

    fnclog "zabbixsender - zabbixitemkey: $zabbixitemkey" 
    fnclog "zabbixsender - zabbixitemkeyvalue: $zabbixitemkeyvalue"
    
    #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k $zabbixitemkey -o "$zabbixitemkeyvalue" -vv
    fnclog "zabbixsender - sendresult : $zabbixsendcommand"
}

function fncscripterrorsend { 
    fnclog "Sending error"
    #fnczabbixsend -zabbixhostname "$zabbixhostname" -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "1"
    exit;
}


fnclog "go" 
fnclog "detect log - log for backupjob '$backupjob' "
$veameventlist = Get-WinEvent -FilterHashtable @{Logname='Veeam Backup';ID=190;StartTime = (Get-Date).AddDays(-1);}
$backupjob_result_log = $veameventlist | where {$_.Message -like "*$($backupjob)*"}

if(-Not $backupjob_result_log){fnclog "detect log - error. not found"; fncscripterrorsend;}
if($backupjob_result_log){
    fnclog "detect log - found"
    $backupjob_result_date = $backupjob_result_log.TimeCreated
    $backupjob_result_message = $backupjob_result_log.Message
    
    fnclog "log message - backupjob_result_date: '$backupjob_result_date'"
    fnclog "log message - backupjob_result_message: '$backupjob_result_message'"

    fnclog "get backupjob result - analyzing..."
    if ($backupjob_result_message -like "*Success*") { 
        fnclog "get backupjob result - found: Success"
        $veeam_backupresult_nr = "1"
    }else{
        fnclog "get backupjob result - found: failed"
        $veeam_backupresult_nr = "2"
    }
    fnclog "veeam_endpoint_backupresult_nr $veeam_backupresult_nr"

    #sending data
    #fnczabbixsend -zabbixitemkey "veeam_endpoint_backupresult_nr" -zabbixitemkeyvalue "$veeam_backupresult_nr"


    #no error found
    #fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0"
} 
fnclog "done"







