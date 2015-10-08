#!/bin/bash

usage()
{
cat << EOF
Get balance script for Vutlan/SkyControl/Zertico monitoring system.
Tested with Zabbix v2.4, bash v4, SkyControl SC8100 fw v2.4.4 b060
usage: $0 options

OPTIONS:
   -?,-h   Show this message
   -H      Hostname or IP address
   -u      User name of user who has the writing rights: 1)GSM modem; 2)SMS; 3) All groups;
   -p      Password of the user
   -m      GSM Modem internal ID
   -U      USSD get balance command 
   -s      Seconds to sleep between sending USSD command and trying to parsing answer 
   -r      Bash regex expression to extract balance (how much money left) from sms-answer
EOF
}



# 192.168.0.193
HOSTIP=
# I recommend add special user with rights: write to GSM modem, SMS, All groups. 
# If u will use guest/guest, u must be relogon to device web interface after each running of script
# smsuser
USERNAME=
# smspassword
PASSWORD=
# 404001
GSMMODEMID=
# *105#
USSD=
# 5
SLEEP=
# OCTATOK ([0-9.]+)
REGEX=



while getopts "hH:u:p:m:U:s:r:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         H)
             HOSTIP=$OPTARG
             ;;
         u)
             USERNAME=$OPTARG
             ;;
         p)
             PASSWORD=$OPTARG
             ;;
         m)
             GSMMODEMID=$OPTARG
             ;;
         U)
             USSD=$OPTARG
             ;;
         s)
             SLEEP=$OPTARG
             ;;
         r)
             REGEX=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
         
     esac
done


if [[ -z $HOSTIP ]] || [[ -z $USERNAME ]] || [[ -z $PASSWORD ]] || [[ -z $GSMMODEMID ]] || [[ -z $USSD ]] || [[ -z $SLEEP ]] || [[ -z $REGEX ]]
then
     usage
     exit 1
fi


# 1) хеш пароля
HASH=`echo -n ${PASSWORD} | openssl dgst -sha1 | awk '{print $NF}'`

# 2) авторизация
RESPONSE=`curl -s -d "querytype=auth&name=${USERNAME}&h=${HASH}" "${HOSTIP}/engine.htm"`

# 3) ключ сессии
KEY=`echo -n  ${RESPONSE} | awk -F"\"" '{print $4}'`

# 4) запросить обновление баланса и подождать
curl -s -d "querytype=updateelement&k=${KEY}&id=${GSMMODEMID}&ctrl=updatebalance" --data-urlencode "balance=${USSD}" ${HOSTIP}/engine.htm > /dev/null 2>&1

sleep $SLEEP

# 5) считать баланс
RESPONSE=`curl -s -d "querytype=getelement&k=${KEY}&id=${GSMMODEMID}" ${HOSTIP}/engine.htm | grep balance`
BALANCE=`echo ${RESPONSE} | awk -F"\"" '{print $4}'`

# taking money left
[[ $BALANCE =~ $REGEX ]]
MONEYLEFT=${BASH_REMATCH[1]}

echo ${MONEYLEFT}
