<#
    
    == Description ===
    Get data from Aruba instant-on api and send it to zabbix.

    This script is a part of a onther script.
    Please change the settings in that script where needed.

#>

#include mainscript
. /usr/local/sbin/zabbix-aruba-instanton-devices_script.ps1

#BMD
fnc_aruba_instanton_devicereader -aiositeid "arubasiteaid" -aiodevicename "mydevicename" -zabbixhostname "zabbixhostname"

