#!/bin/bash

# hash arrays is exists since Bash 4 !!! 
declare -A arrElemType arrElemName


usage()
{
cat << EOF
Generate Zabbix LLD-like JSON for Vutlan / SkyControl / Zertico master-modules
Tested with Zabbix 2.4, net-snmp v5.4, bash v4, SkyControl SC8100 fw v2.4.4 b060
usage: $0 options

OPTIONS:
   -?,-h   Show this message
   -c      SNMP v2c community
   -H      Discovered host
   -t      Type of sensors (dry, temperature, voltage, etc)
EOF
}


discoveredHost=
community="public"
snmpwalk_cmd="/usr/bin/snmpwalk"

# get options from commandline
while getopts "hH:c:t:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         H)
             discoveredHost=$OPTARG
             ;;
         c)
             community=$OPTARG
             ;;
         t)
             elemType=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;

     esac
done

if [[ -z $discoveredHost ]] || [[ -z $community ]] || [[ -z $elemType ]]
then
     usage
     exit 1
fi

# Element types subtree OID
oidType=".1.3.6.1.4.1.39052.1.3.1.6"
# Element names subtree OID
oidName=".1.3.6.1.4.1.39052.1.3.1.7"

# walk to subtrees with given options and make output in _ascii_ numeric and quick print (important!)
snmpwalk_cmd="$snmpwalk_cmd $discoveredHost -Oaqn -v 2c -c $community "

# read snmp indexes of element with some type to array (hash). Hashes works since bash v4 (!) 
while read idx; do
        arrElemType[$idx]=$idx
done < <($snmpwalk_cmd $oidType | grep $elemType | sed "s/$oidType.//" | awk '{print $1}')

# read names of element, which indexes exists in type array (i.e. has given type), to array.
while read idx value; do
        if [ ${arrElemType[$idx]} ] 
        then
           arrElemName[$idx]=$value
        fi
done < <($snmpwalk_cmd $oidName | sed "s/$oidName.//;s/\"\(.*\)\"/\1/")

# get length of array
maxIdx=${#arrElemName[*]}

nCnt=0

# print head of JSON 
echo -e "{\n\t\"data\": ["
for idx in ${!arrElemName[*]}
do
  # print snmp index and name of each element 
  # i try to use printf and got error with names, which contain "()", 
  echo -e "\n\t\t{ \"{#SNMPINDEX}\":\"$idx\", \"{#ELEMENTNAME}\":\"${arrElemName[$idx]}\" }"  
  ((nCnt++))
  # print comma until not printed last element
  if (( $nCnt < $maxIdx ))
  then
    printf ","
  fi
done

# print tail of JSON 
echo -e "\n\t]\n}\n"

