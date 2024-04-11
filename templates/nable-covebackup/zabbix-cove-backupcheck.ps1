<#
    ###################
    #== Description ===
    ###################
    Script that checks cove backups.

    Installation:
    1. create a cove account.
    2. enable on this "API Authentication"
    3. enter the login data in settings section of this script.
#>

Param(
    [Parameter(Mandatory = $true)] [string] $zabbixhostname,
    [Parameter(Mandatory = $false)] [string] $CustomerID
)   






####################
## Login settings - user
####################
$apiurl= "https://api.backup.management/jsonapi"
$api_account_username = "firname.lastname@myfirm.com"
$api_account_password = "mypassword"
$api_account_partner = "My firm"

##################
## Script settings
##################

#ipadres zabbix server or zabbix proxy
$zabbixserver ="172.20.1.106"
$zabbixscript_title = "Cove Backupcheck"
$zabbixscripterror_itemkey = "cove_scripterror"

##running this script using powershell for windows
##folderpath of zabbix agent
#$zabbixsenderfolder="C:\Program Files\Zabbix Agent"
##filename of zabbix agent
#$zabbixsenderexecfile ="zabbix_sender.exe"

#running this script using powershell for linux, uncomment the following lines:
##folderpath of zabbix agent
$zabbixsenderfolder="/usr/bin/" 
##filename of zabbix agent
$zabbixsenderexecfile="zabbix_sender"

# Dont change anything, behind the following line
#=====================================================
#=====================================================
#=====================================================
#=====================================================
#=====================================================

#
write-host "Cove Backupcheck - Script loaded"


                        

        ###########################
        ## Script functions - start
        ##########################
        
        function fncGetLogTimeStamp {return "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)}
        function fnclog($logtext){Write-host "$(fncGetLogTimeStamp) $zabbixscript_title - $logtext";}

        Function fnczabbixsend()
        {
            Param([Parameter(Mandatory = $true)] [string] $zabbixitemkey,[Parameter(Mandatory = $false)] [string] $zabbixitemkeyvalue)   
            #function description: to send data to zabbix server with zabbix sender
            fnclog "zabbixsender - zabbixitemkey / value: '$zabbixitemkey' - '$zabbixitemkeyvalue'";
            #$zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k $zabbixitemkey -o "$zabbixitemkeyvalue" -vv;
            $zabbixsendcommand = .$zabbixsenderfolder\$zabbixsenderexecfile -z $zabbixserver -s $zabbixhostname -k $zabbixitemkey -o "$zabbixitemkeyvalue";
            fnclog "zabbixsender - $zabbixsendcommand"
        }

        #function fncscripterrorsend { fnclog "Sending error"; fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "1"; exit; }
        function fncscripterrorsend { fnclog "Sending error"; fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "1"; exit;}

        Function fncConvert_UnixTimeToDateTime($unixtime){$epoch = Get-Date -UnixTimeSeconds $unixtime -Format 'yyyyMMdd-HHmm';return $epoch;}   

        ############################
        ## Script functions - End ##
        ############################


        ###########
        ## Login ##
        ###########

        fnclog "Start"

        ##login with cove
        fnclog "Login - Go"
        $loginbody =  @{
            "jsonrpc"= "2.0"
            "method"= "Login"
            "params"= @{
                "partner"="$api_account_partner"
                "username"="$api_account_username"
                "password"="$api_account_password"
            }
            "id"= "1"
        } | ConvertTo-Json
        $login = Invoke-WebRequest -Uri $apiurl -Method 'POST' -Body $loginbody | ConvertFrom-Json
        if ($login.visa){fnclog "Login - OK";}else{fnclog "Login - error"; fncscripterrorsend;}

        #Set visa
        $visa = $login.visa
        if ($visa) { fnclog "Login - API Visa registered"} else { fnclog "Login - Error - API Visa not registered"}

        
        ##########
        ## Data ##
        ##########
        
        [int]$partnerId_search1=$CustomerID
        #fnclog "Partner info - Getting data for Customer: $CustomerName"
        fnclog "Partner info - Getting data for Customer-id: $partnerId_search1"

        #info: https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/get-customer-info.htm
        #api querry
        <#
        #search in customer name
        $bodypartner =  @{
            "id"= "jsonrpc"
            "jsonrpc"="2.0"
            "visa"= "$visa"
            "method"="GetPartnerInfo"
            "params"=@{
                "name"="$CustomerName"
            }
        } | ConvertTo-Json
        #>
        $bodypartner =  @{
            "id"= "jsonrpc"
            "jsonrpc"="2.0"
            "visa"= "$visa"
            "method"="GetPartnerInfoById"
            "params"=@{
                "partnerId"=$partnerId_search1
            }
        } | ConvertTo-Json
        $responsepartner1 = Invoke-WebRequest -Uri "$apiurl" -Method 'POST' -Body $bodypartner
        $partnerinfo = ([System.Text.Encoding]::UTF8.GetString($responsepartner1.Content) | ConvertFrom-Json).result.result
        

        <#
        #check if it is the right partner info
        if ($partnerinfo.Name -EQ $CustomerName){fnclog "Partner info - found Customer"; fnclog "";}else{ fnclog "Partner info - Error not found Customer '$($CustomerName)'"; fncscripterrorsend; }
        #>

        ##########
        ## Data ##
        ##########

        fnclog "******************"
        fnclog "** Partner info **"
        fnclog "******************"

        #if parterner if found, set data
        $partnerid = $partnerinfo.Id
        $Partner_PartnerId = [int]$partnerinfo.Id
        $Partner_Name = $partnerinfo.Name
        fnclog "Partner info - Partner_PartnerId: $Partner_PartnerId"
        fnclog "Partner info - Partner_Name: $Partner_Name"

        #################
        ## Device Data ##
        #################

        fnclog  ""
        fnclog "Device - Getting info..."
        fnclog  ""
        fnclog "************"
        fnclog "** Device **"
        fnclog "************"


        #info
        #https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/enumerate-device-statistics.htm
        #https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/API-column-codes.htm
        #https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/enumerate-device-statistics.htm#AccountStatisticsQueryChild
        #tabel kijkt naar https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/API-column-codes-legacy.htm
        # nieuwe tabel https://documentation.n-able.com/covedataprotection/USERGUIDE/documentation/Content/service-management/json-api/API-column-codes.htm


        #device querry colmnarrays
        #$devicequerydata_columnarray_normal = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","OT","PD","AP","PF","PN","CD","TS","TL","T3","US","TB","I81","AA843","AA77","AA2048","GL","JL")
        #$devicequerydata_columnarray_onedrive_oud = @("T7","T1","T2","TQ","TJ","TO","TB","TM","J0","J1","J2","J3","J4","J5","J6","J7","JA","JL","JQ","JJ","JO","JR","JB","JK","JM")
        #$devicequerydata_columnarray_exchange_oud = @("G0","G1","G2","G3","G4","G5","G6","G7","GA","GL","GQ","GJ","GO","GR","GB","GK","GM")
        #$devicequerydata_columnarray_sharepoint_oud =  @("P0","P1","P2","P3","P4","P5","P6","P7","PA","PL","PQ","PJ","PO","PR","PB","PK")
        $devicequerydata_columnarray_device_new = @("I0","I1","I2","I4","I5","I8","I9","I10","I15","D19I1")
        $devicequerydata_columnarray_ondedrive_new =  @("D20F01","D20F01","D20F02","D20F03","D20F04","D20F05","D20F06","D20F07","D20F08","D20F09","D20F10","D20F11","D20F12","D20F13","D20F14","D20F15","D20F16","D20F17","D20F18","D20F19","D20F20","D20F21")
        $devicequerydata_columnarray_exchange_new =  @("D19F01","D19F01","D19F02","D19F03","D19F04","D19F05","D19F06","D19F07","D19F08","D19F09","D19F10","D19F11","D19F12","D19F13","D19F14","D19F15","D19F16","D19F17","D19F18","D19F19","D19F20","D19F21")
        $devicequerydata_columnarray_sharepoint_new =  @("D5F01","D5F01","D5F02","D5F03","D5F04","D5F05","D5F06","D5F07","D5F08","D5F09","D5F10","D5F11","D5F12","D5F13","D5F14","D5F15","D5F16","D5F17","D5F18","D5F19","D5F20","D5F21")
        $devicequerydata_columnarray_teams_new =  @("D23F01","D23F01","D23F02","D23F03","D23F04","D23F05","D23F06","D23F07","D23F08","D23F09","D23F10","D23F11","D23F12","D23F13","D23F14","D23F15","D23F16","D23F17","D23F18","D23F19","D23F20","D23F21")
        
        #device querry colmnarrays all
        $devicequerydata_columnarray_all = $devicequerydata_columnarray_device_new +  $devicequerydata_columnarray_ondedrive_new + $devicequerydata_columnarray_exchange_new + $devicequerydata_columnarray_sharepoint_new + $devicequerydata_columnarray_teams_new

        #select device array
        $devicequerydata_columnarray =  $devicequerydata_columnarray_all

        #device query
        [int]$DeviceCount = 5000
        $devicequerydata = @{}
        $devicequerydata.jsonrpc = '2.0'
        $devicequerydata.id = '2'
        $devicequerydata.visa = $visa
        $devicequerydata.method = 'EnumerateAccountStatistics'
        $devicequerydata.params = @{}
        $devicequerydata.params.query = @{}
        $devicequerydata.params.query.PartnerId = [int]$PartnerId
        $devicequerydata.params.query.Filter = $Filter1
        $devicequerydata.params.query.Columns = $devicequerydata_columnarray
        $devicequerydata.params.query.OrderBy = "CD DESC"
        $devicequerydata.params.query.StartRecordNumber = 0
        $devicequerydata.params.query.RecordsCount = $devicecount
        $devicequerydata.params.query.Totals = @("COUNT(AT==1)","SUM(T3)","SUM(US)")

        #$devicequery jsondata
        $devicequeryjsondata = (ConvertTo-Json $devicequerydata -depth 6)
        #$devicequery params    
        $devicequeryparams = @{
            Uri         = $apiurl
            Method      = 'POST'
            Headers     = @{ 'Authorization' = "Bearer $visa" }
            Body        = ([System.Text.Encoding]::UTF8.GetBytes($devicequeryjsondata))
            ContentType = 'application/json; charset=utf-8'
        } 
        #device query execute
        $DeviceResponse = Invoke-RestMethod @devicequeryparams
        $DeviceResult = $DeviceResponse.result.result.Settings

        #get device results

        #fnclog "Device ID: $($DeviceResult.I0)"
        $cove_device_DevID = $([string]$DeviceResult.D19F06).Trim()
        fnclog "Device - Device ID: $cove_device_DevID"
        #fnclog "Device name: $($DeviceResult.I1)"
        [int] $cove_device_DevName = $([string]$DeviceResult.I4).Trim()
        fnclog "Device - Device name: $cove_device_DevName"
        #fnclog "Device name alias $($DeviceResult.I2)"
        #fnclog "Creation date $($DeviceResult.I4)"
        [int] $cove_device_Creationdate1 = $([string]$DeviceResult.I4).Trim()
        $cove_device_Creationdate = fncConvert_UnixTimeToDateTime $cove_device_Creationdate1
        fnclog "Device - Creation date: $cove_device_Creationdate"
        [int]$cove_device_Expirationdate1 = $([string] $DeviceResult.I5).Trim()
        $cove_device_Expirationdate = fncConvert_UnixTimeToDateTime $cove_device_Expirationdate1
        fnclog "Device - Expiration date: $cove_device_Expirationdate"
        $cove_device_Customer = $([string]$DeviceResult.I8).Trim() 
        fnclog "Device - Customer: $cove_device_Customer"
        #$cove_device_ProductID = $([string]$DeviceResult.I9).Trim()
        #fnclog "Device - Product ID: $cove_device_ProductID"
        #$cove_device_Product = $([string]$DeviceResult.I10).Trim()
        #fnclog "Device - Product: $cove_device_Product"
        #fnclog "Password: $($DeviceResult.I3)"
        #fnclog "Email: $($DeviceResult.I15)"
        #fnclog "Retention units: $($DeviceResult.I39)"
        #fnclog "Profile ID: $($DeviceResult.I54)"


        fnclog "Device - Expiration date - expiration check"
        $datecurrent = Get-Date
        $cove_device_Expirationdate1_compare = Get-Date -UnixTimeSeconds $cove_device_Expirationdate1
        fnclog "Device - expiration check - currdate '$($datecurrent)'"  
        fnclog "Device - expiration check - Expidate '$($cove_device_Expirationdate1_compare)'"
        if ($datecurrent -lt $cove_device_Expirationdate1_compare){fnclog "Device - expiration check - ok";$cove_device_Expirated="0";}else{fnclog "Device - expiration check - not ok"; $cove_device_Expirated="1";}



        fnclog ""
        fnclog "*****************"
        fnclog "** MS exchange **"
        fnclog "*****************"
        fnclog ""

        #fnclog "MS exchange - Last Session Selected Count $($DeviceResult.D19F01)"
        #fnclog "MS exchange - Last Session Processed Count $($DeviceResult.D19F02)"
        #fnclog "MS exchange - Last Session Selected Size $($DeviceResult.D19F03)"
        #fnclog "MS exchange - Last Session Processed Size $($DeviceResult.D19F04)"
        #fnclog "MS exchange - Last Session Sent Size $($DeviceResult.D19F05)"
        #fnclog "MS exchange - Last Session Errors Count $($DeviceResult.D19F06)"
        $cove_msex_LastSessionErrorsCount = $([string]$DeviceResult.D19F06).Trim()
        fnclog "MS exchange - Last Session Errors Count test: $cove_msex_LastSessionErrorsCount"
        #fnclog "MS exchange - Protected size $($DeviceResult.D19F07)"
        #fnclog "MS exchange - Color bar – last 28 days $($DeviceResult.D19F08)"
        #fnclog "MS exchange - Last successful session Timestamp: $($DeviceResult.D19F09)"
        [int] $cove_msex_LastsuccessfulsessionTimestamp1 = $([string]$DeviceResult.D19F09).Trim()
        $cove_msex_LastsuccessfulsessionTimestamp = fncConvert_UnixTimeToDateTime $cove_msex_LastsuccessfulsessionTimestamp1
        fnclog "MS exchange - Last successful session Timestamp test: $cove_msex_LastsuccessfulsessionTimestamp"
        #fnclog "MS exchange - Pre Recent Session Selected Count: $($DeviceResult.D19F10)"
        #fnclog "MS exchange - Pre Recent Session Selected Size: $($DeviceResult.D19F11)"
        #fnclog "MS exchange - Session duration $($DeviceResult.D19F12)"
        #fnclog "MS exchange - Last Session License Items count ? $($DeviceResult.D19F13)"
        #fnclog "MS exchange - Retention $($DeviceResult.D19F14)"
        [int] $cove_msex_LastSessionTimestamp1 = $([string]$DeviceResult.D19F15).Trim()
        $cove_msex_LastSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_msex_LastSessionTimestamp1
        fnclog "MS exchange - Last Session Timestamp: $cove_msex_LastSessionTimestamp"
        $cove_msex_LastSuccessfulSessionStatus = $([string]$DeviceResult.D19F16).Trim()
        fnclog "MS exchange - Last Successful Session Status: $cove_msex_LastSuccessfulSessionStatus"
        $cove_msex_LastCompletedSessionStatus = $([string]$DeviceResult.D19F17).Trim()
        fnclog "MS exchange - Last Completed Session Status: $cove_msex_LastCompletedSessionStatus"
        [int] $cove_msex_LastCompletedSessionTimestamp1 = $([string]$DeviceResult.D19F18).Trim()
        $cove_msex_LastCompletedSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_msex_LastCompletedSessionTimestamp1
        fnclog "MS exchange - Last Completed Session Timestamp: $cove_msex_LastCompletedSessionTimestamp"
        #fnclog "MS exchange - Last Session Verification Data: $($DeviceResult.D19F19)"
        #fnclog "MS exchange - Last Session User Mailboxes Count: $($DeviceResult.D19F20)"
        #fnclog "MS exchange - Last Session Shared Mailboxes Count: ? $($DeviceResult.D19F21)"

        fnclog ""
        fnclog "*****************"
        fnclog "** MS Onedrive ** "
        fnclog "*****************"
        fnclog ""

        #fnclog "onedrive - Last Session Selected Count: $($DeviceResult.D20F01)"
        #fnclog "onedrive - Last Session Processed Count: $($DeviceResult.D20F02)"
        #fnclog "onedrive - Last Session Selected Size: $($DeviceResult.D20F03)"
        #fnclog "onedrive - Last Session Processed Size: $($DeviceResult.D20F04)"
        #fnclog "onedrive - Last Session Sent Size: $($DeviceResult.D20F05)"
        $cove_msod_LastSessionErrorsCount = $([string]$DeviceResult.D20F06).Trim()
        fnclog "onedrive - Last Session Errors Count: '$cove_msod_LastSessionErrorsCount'"
        #fnclog "onedrive - Protected size: $($DeviceResult.D20F07)"
        #$cove_msod_ColorbarLast28days = $([string]$DeviceResult.D20F08).Trim()
        #fnclog "onedrive - Color bar – last 28 days: $cove_msod_ColorbarLast28days"
        [int] $cove_msod_LastsuccessfulsessionTimestamp1 = $([string]$DeviceResult.D20F09).Trim()
        $cove_msod_LastsuccessfulsessionTimestamp = fncConvert_UnixTimeToDateTime $cove_msod_LastsuccessfulsessionTimestamp1
        fnclog "onedrive - Last successful session Timestamp: $cove_msod_LastsuccessfulsessionTimestamp"
        #fnclog "onedrive - Pre Recent Session Selected Count: $($([string]$DeviceResult.D20F10).Trim())"
        #fnclog "onedrive - Pre Recent Session Selected Size: $($DeviceResult.D20F11)"
        #fnclog "onedrive - Session duration: $($DeviceResult.D20F12)"
        #fnclog "onedrive - Last Session License Items count ?: $($DeviceResult.D20F13)"
        #fnclog "onedrive - Retention: $($DeviceResult.D20F14)"
        [int] $cove_msod_LastSessionTimestamp1 = $([string]$DeviceResult.D20F15).Trim()
        $cove_msod_LastSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_msod_LastSessionTimestamp1
        fnclog "onedrive - Last Session Timestamp: $cove_msod_LastSessionTimestamp"
        $cove_msod_LastSuccessfulSessionStatus = $([string]$DeviceResult.D20F16).Trim()
        fnclog "onedrive - Last Successful Session Status: $cove_msod_LastSuccessfulSessionStatus"
        $cove_msod_LastCompletedSessionStatus = $([string]$DeviceResult.D20F17).Trim()
        fnclog "onedrive - Last Completed Session Status: $cove_msod_LastCompletedSessionStatus"
        [int] $cove_msod_LastCompletedSessionTimestamp1 = $([string]$DeviceResult.D20F18).Trim()
        $cove_msod_LastCompletedSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_msod_LastCompletedSessionTimestamp1
        fnclog "onedrive - Last Completed Session Timestamp: $cove_msod_LastCompletedSessionTimestamp"
        #fnclog "onedrive - Last Session Verification Data: $($DeviceResult.D20F19)"
        #fnclog "onedrive - Last Session User Mailboxes Count: $($DeviceResult.D20F20)"
        #fnclog "onedrive - Last Session Shared Mailboxes Count ?: $($DeviceResult.D20F21)"

        fnclog ""
        fnclog "*****************"
        fnclog "** SharePoint **"
        fnclog "*****************"
        fnclog ""

        #fnclog "Sharepoint - Last Session Selected Count: $($DeviceResult.D5F01)"
        #fnclog "Sharepoint - Last Session Processed Count: $($DeviceResult.D5F02)"
        #fnclog "Sharepoint - Last Session Selected Size: $($DeviceResult.D5F03)"
        #fnclog "Sharepoint - Last Session Processed Size: $($DeviceResult.D5F04)"
        #fnclog "Sharepoint - Last Session Sent Size: $($DeviceResult.D5F05)"
        $cove_sp_LastSessionErrorsCount = $([string]$DeviceResult.D5F06).Trim()
        fnclog "Sharepoint - Last Session Errors Count: $cove_sp_LastSessionErrorsCount"
        #fnclog "Sharepoint - Protected size: $($DeviceResult.D5F07)"
        #fnclog "Sharepoint - Color bar – last 28 days: $($([string]$DeviceResult.D5F08).Trim())"
        [int] $cove_sp_LastsuccessfulsessionTimestamp1 = $([string]$DeviceResult.D5F09).Trim()
        $cove_sp_LastsuccessfulsessionTimestamp = fncConvert_UnixTimeToDateTime $cove_sp_LastsuccessfulsessionTimestamp1
        fnclog "Sharepoint - Last successful session Timestamp: $cove_sp_LastsuccessfulsessionTimestamp"
        #fnclog "Sharepoint - Pre Recent Session Selected Count: $($DeviceResult.D5F10)"
        #fnclog "Sharepoint - Pre Recent Session Selected Size: $($DeviceResult.D5F11)"
        #fnclog "Sharepoint - Session duration: $($DeviceResult.D5F12)"
        #fnclog "Sharepoint - Last Session License Items count ?: $($DeviceResult.D5F13)"
        #fnclog "Sharepoint - Retention: $($DeviceResult.D5F14)"
        [int] $cove_sp_LastSessionTimestamp1 = $([string]$DeviceResult.D5F15).Trim()
        $cove_sp_LastSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_sp_LastSessionTimestamp1
        fnclog "Sharepoint - Last Session Timestamp: $cove_sp_LastSessionTimestamp"
        $cove_sp_LastSuccessfulSessionStatus = $([string]$DeviceResult.D5F16).Trim()
        fnclog "Sharepoint - Last Successful Session Status: $cove_sp_LastSuccessfulSessionStatus"
        $cove_sp_LastCompletedSessionStatus = $([string]$DeviceResult.D5F17).Trim()
        fnclog "Sharepoint - Last Completed Session Status: $cove_sp_LastCompletedSessionStatus"
        [int] $cove_sp_LastCompletedSessionTimestamp1 = $([string]$DeviceResult.D5F18).Trim()
        $cove_sp_LastCompletedSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_sp_LastCompletedSessionTimestamp1
        fnclog "Sharepoint - Last Completed Session Timestamp: $cove_sp_LastCompletedSessionTimestamp"
        #fnclog "Sharepoint - Last Session Verification Data: $($DeviceResult.D5F19)"
        #fnclog "Sharepoint - Last Session User Mailboxes Count: $($DeviceResult.D5F20)"
        #fnclog "Sharepoint - Last Session Shared Mailboxes Count ?: $($DeviceResult.D5F21)"


        fnclog ""
        fnclog "***********"
        fnclog "** Teams **"
        fnclog "***********"
        fnclog ""

        #fnclog "Teams - Last Session Selected Count: $($DeviceResult.D23F01)"
        #fnclog "Teams - Last Session Processed Count: $($DeviceResult.D23F02)"
        #fnclog "Teams - Last Session Selected Size: $($DeviceResult.D23F03)"
        #fnclog "Teams - Last Session Processed Size: $($DeviceResult.D23F04)"
        #fnclog "Teams - Last Session Sent Size: $($DeviceResult.D23F05)"
        $cove_teams_LastSessionErrorsCount = $([string]$DeviceResult.D23F06).Trim()
        fnclog "Teams - Last Session Errors Count: $cove_teams_LastSessionErrorsCount"
        #fnclog "Teams - Protected size: $($DeviceResult.D23F07)"
        #fnclog "Teams - Color bar – last 28 days: $($([string]$DeviceResult.D23F08).Trim())"
        [int] $cove_teams_LastsuccessfulsessionTimestamp1 = $([string]$DeviceResult.D23F09).Trim()
        $cove_teams_LastsuccessfulsessionTimestamp = fncConvert_UnixTimeToDateTime $cove_teams_LastsuccessfulsessionTimestamp1
        fnclog "Teams - Last successful session Timestamp: $cove_teams_LastsuccessfulsessionTimestamp"
        #fnclog "Teams - Pre Recent Session Selected Count: $($DeviceResult.D23F10)"
        #fnclog "Teams - Pre Recent Session Selected Size: $($DeviceResult.D23F11)"
        #fnclog "Teams - Session duration: $($DeviceResult.D23F12)"
        #fnclog "Teams - Last Session License Items count ?: $($DeviceResult.D23F13)"
        #fnclog "Teams - Retention: $($DeviceResult.D23F14)"
        [int] $cove_teams_LastSessionTimestamp1 = $([string]$DeviceResult.D23F15).Trim()
        $cove_teams_LastSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_teams_LastSessionTimestamp1
        fnclog "Teams - Last Session Timestamp: $cove_teams_LastSessionTimestamp"
        $cove_teams_LastSuccessfulSessionStatus = $([string]$DeviceResult.D23F16).Trim()
        fnclog "Teams - Last Successful Session Status: $cove_teams_LastSuccessfulSessionStatus"
        $cove_teams_LastCompletedSessionStatus = $([string]$DeviceResult.D23F17).Trim()
        fnclog "Teams - Last Completed Session Status: $cove_teams_LastCompletedSessionStatus"
        [int] $cove_teams_LastCompletedSessionTimestamp1 = $([string]$DeviceResult.D23F18).Trim()
        $cove_teams_LastCompletedSessionTimestamp = fncConvert_UnixTimeToDateTime $cove_teams_LastCompletedSessionTimestamp1
        fnclog "Teams - Last Completed Session Timestamp: $cove_teams_LastCompletedSessionTimestamp"
        #fnclog "Teams - Last Session Verification Data: $($DeviceResult.D23F19)"
        #fnclog "Teams - Last Session User Mailboxes Count: $($DeviceResult.D23F20)"
        #fnclog "Teams - Last Session Shared Mailboxes Count ?: $($DeviceResult.D23F21)"


        ###############
        ## Data Send ##
        ###############

        fnclog ""
        fnclog "=================="
        fnclog "== sending data =="
        fnclog "=================="
        fnclog ""

        fnczabbixsend -zabbixitemkey "cove_device_Customer" -zabbixitemkeyvalue "$cove_device_Customer"
        fnczabbixsend -zabbixitemkey "cove_device_Expirationdate" -zabbixitemkeyvalue "$cove_device_Expirationdate"
        fnczabbixsend -zabbixitemkey "cove_device_Expirated" -zabbixitemkeyvalue "$cove_device_Expirated"
        fnczabbixsend -zabbixitemkey "cove_msex_LastSessionErrorsCount" -zabbixitemkeyvalue "$cove_msex_LastSessionErrorsCount"
        fnczabbixsend -zabbixitemkey "cove_msex_LastsuccessfulsessionTimestamp" -zabbixitemkeyvalue "$cove_msex_LastsuccessfulsessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_msex_LastSessionTimestamp" -zabbixitemkeyvalue "$cove_msex_LastSessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_msex_LastSuccessfulSessionStatus" -zabbixitemkeyvalue "$cove_msex_LastSuccessfulSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_msex_LastCompletedSessionStatus" -zabbixitemkeyvalue "$cove_msex_LastCompletedSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_msex_LastCompletedSessionTimestamp" -zabbixitemkeyvalue "$cove_msex_LastCompletedSessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_msod_LastSessionErrorsCount" -zabbixitemkeyvalue "$cove_msod_LastSessionErrorsCount"
        fnczabbixsend -zabbixitemkey "cove_msod_LastsuccessfulsessionTimestamp" -zabbixitemkeyvalue "$cove_msod_LastsuccessfulsessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_msod_LastSessionTimestamp" -zabbixitemkeyvalue "$cove_msod_LastSessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_msod_LastSuccessfulSessionStatus" -zabbixitemkeyvalue "$cove_msod_LastSuccessfulSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_msod_LastCompletedSessionStatus" -zabbixitemkeyvalue "$cove_msod_LastCompletedSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_msod_LastCompletedSessionTimestamp" -zabbixitemkeyvalue "$cove_msod_LastCompletedSessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_sp_LastSessionErrorsCount" -zabbixitemkeyvalue "$cove_sp_LastSessionErrorsCount"
        fnczabbixsend -zabbixitemkey "cove_sp_LastsuccessfulsessionTimestamp" -zabbixitemkeyvalue "$cove_sp_LastsuccessfulsessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_sp_LastSessionTimestamp" -zabbixitemkeyvalue "$cove_sp_LastSessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_sp_LastSuccessfulSessionStatus" -zabbixitemkeyvalue "$cove_sp_LastSuccessfulSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_sp_LastCompletedSessionStatus" -zabbixitemkeyvalue "$cove_sp_LastCompletedSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_sp_LastCompletedSessionTimestamp" -zabbixitemkeyvalue "$cove_sp_LastCompletedSessionTimestamp"
        
        fnczabbixsend -zabbixitemkey "cove_teams_LastSessionErrorsCount" -zabbixitemkeyvalue "$cove_teams_LastSessionErrorsCount"
        fnczabbixsend -zabbixitemkey "cove_teams_LastsuccessfulsessionTimestamp" -zabbixitemkeyvalue "$cove_teams_LastsuccessfulsessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_teams_LastSessionTimestamp" -zabbixitemkeyvalue "$cove_teams_LastSessionTimestamp"
        fnczabbixsend -zabbixitemkey "cove_teams_LastSuccessfulSessionStatus" -zabbixitemkeyvalue "$cove_teams_LastSuccessfulSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_teams_LastCompletedSessionStatus" -zabbixitemkeyvalue "$cove_teams_LastCompletedSessionStatus"
        fnczabbixsend -zabbixitemkey "cove_teams_LastCompletedSessionTimestamp" -zabbixitemkeyvalue "$cove_teams_LastCompletedSessionTimestamp"

        #send scripterror 0
        fnczabbixsend -zabbixitemkey "$zabbixscripterror_itemkey" -zabbixitemkeyvalue "0";

        fnclog ""
        fnclog "END Script"


#fnccovebackupcheck -zabbixhostname "Bobeldijk-Covebackup" -CustomerName "Bobeldijk Food Group B.V."
#>