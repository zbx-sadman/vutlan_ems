#!/bin/bash

ToPhone=$1
Subj=$2
# need to convert " -> '. Otherwise curl can't send message to SkyControl master-module 
Message=$(sed "s/\"/'/g" <<< $3)
echo $Message

GSMGateHost="172.16.100.231"
GSMGateUser="smssender"
GSMGatePass="I9oIcdTn"

PassHASH=`echo -n ${GSMGatePass} | openssl dgst -sha1 | awk '{print $NF}'`
Response=`curl -s -d "querytype=auth&name=${GSMGateUser}&h=${PassHASH}" "${GSMGateHost}/engine.htm"`
SessionKey=`echo -n  ${Response} | awk -F"\"" '{print $4}'`
curl -d "querytype=send_sms_message&k=${SessionKey}" --data-urlencode "to_phone=${ToPhone}" --data-urlencode "message=${Message}" ${GSMGateHost}/engine.htm > /dev/null 2>&1
