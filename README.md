# Zabbix Template & external scripts for Vutlan(SkyControl) EMS 

Implemented:
- LLD and control state of door / dry contacts and iButton sensor;
- LLD and control state of humidity / smoke / temperature / voltage / water leak sensors;
- LLD and control state of relays / outlets;
- LLD for GSM modems and control of account balance.

Installation:
- Be sure that bash v4 is installed;
- Place [externalscripts/DiscoverySensors.sh](https://raw.githubusercontent.com/zbx-sadman/vutlan_ems/master/externalscripts/DiscoverySensors.sh), [externalscripts/GSMModemGetBalance.sh.sh](https://raw.githubusercontent.com/zbx-sadman/vutlan_ems/master/externalscripts/GSMModemGetBalance.sh) to Zabbix's ExternalScript dir and make its executable;
- See to Template's Macro tab and change default values if need or rewrite its on Host level.

Tested on SC8110.

Bonus:  
- [_SendSMSWithSkyControl.sh_](https://raw.githubusercontent.com/zbx-sadman/vutlan_ems/master/alertscripts/SendSMSWithSkyControl.sh) - Command-line tool for sending SMS via Vutlan(SkyControl) device.
- [_DiscoverySNMPTrees.sh_](https://raw.githubusercontent.com/zbx-sadman/vutlan_ems/master/externalscripts/DiscoverySNMPTrees.sh) - Command-line tool for discovery various SNMP trees, composite its by SNMP Index and make LLD-JSON.




