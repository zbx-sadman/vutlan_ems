#!/bin/bash

# Associative arrays is exists since Bash 4 !!! 
# Need separate arrIndexes, because bash haven't multidimenesional arrays and need to fake index
# arrValues will have indexes ["idx,0"], ["idx,2"]..., not [idx][0], [idx][2].
declare -A arrValues arrIndexes
declare -a arrMacroNames

usage()
{
# 17 apr 2015 - fixed wrong JSON output with printf function, wrong parsing SNMPwalk result with OIDs, that have empty value and do some optimization of code
# 03 apr 2015 - first public version
cat << EOF
Zabbix LLD-like JSON generator for given Base OID and a number additional subtrees synced with Base OID by snmp indexes
Tested with Zabbix 2.4, net-snmp v5.4, bash v4
17 apr 2015, sadman(at)sfi.komi.com

usage: $0 options MacroName:]OIDOfBaseSubtree [[MacroName:]OIDofAdditionalSubtree ...]
example: $0 -c public -f net.eth.discovery -s localhost SNMPVALUE:.1.3.6.1.2.1.2.2.1.3 IFNAME:.1.3.6.1.2.1.31.1.1.1.1 .1.3.6.1.2.1.2.2.1.5

OPTIONS:
   -?,-h   Show this message
   -c      SNMP v2c community
   -k      fake key (any data)
   -s      Discovered host
   -r      user regexp

EOF
}

splitByRegex(){
   # $1 - Data
   # $2 - Regex
   # $..[1] - first part 
   # $..[2] - second part 
   [[ $1 =~ $2 ]]
   echo ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}
}

makeMacroName(){
   # $1 - macroName
   # $2 - colNumber
   # If $1=nothing, then $1 is $2 (colNumber)
   #  probaly no macroName.
   [ "$#" -eq "1" ] && echo "SNMPVALUE$1" || echo $1
}

# 06/04/2015 - added -r, -k args

discoveredHost=
community=
snmpwalk_cmd="/usr/bin/snmpwalk"
oidBase=
fRegex=false
userNeedRegex=false
userRegex="(.+)?"

# get options from commandline
while getopts "hfr:s:c:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         s)
             discoveredHost=$OPTARG
             ;;
         c)
             community=$OPTARG
             ;;
         r)
             userRegex=$OPTARG
             userNeedRegex=true
             ;;
         ?)
             usage
             exit
             ;;

     esac
done

# How much additional subtree OIDs we have?
numOIDs=$((${#@}-$OPTIND+1))

if [[ -z $discoveredHost ]] || [[ -z $community ]] || (( $numOIDs <= 0 ))
then
     usage
     exit 1
fi

# we put index to ${BASH_REMATCH[1]} and last part of string after [:space:] to ${BASH_REMATCH[1]}. Then we don't need use awk and haven't split bug with
# snmp values, which contain awk-s separator.
snmpRegex="^([0-9]+)[\s]?(.+)?"
argRegex="^([A-Za-z]+?)[:]?([0-9.]+)"

# get Base data from positional argument #0
read macroBase oidBase <<< $(splitByRegex ${@:$OPTIND:1} $argRegex)
# check macroBase and make default name if is nulled
read macroBase <<<  $(makeMacroName $macroBase 0)
arrMacroNames[0]=$macroBase

# walk to subtrees with given options and make output in _ascii_ numeric and quick print (important!)
snmpwalk_cmd="$snmpwalk_cmd $discoveredHost -Oaqn -v 2c -c $community "

# Read snmp elements from base subtree and put they indexes and values to associative arrays, which [hash] index = index/value
# Hashes works since bash v4 (!) 
while read snmpData; do
   # split data by regex to index and other part - value
   read snmpIdx snmpValue <<< $(splitByRegex "$snmpData" "$snmpRegex")
   if [ userNeedRegex ]; then
    if  [[ $snmpValue =~ $userRegex ]]; then 
#    echo ">>$snmpIdx<<   >>$snmpValue<<"
       arrValues[$snmpIdx,0]=$snmpValue; 
       arrIndexes[$snmpIdx]=$snmpIdx
    fi
   fi
done < <($snmpwalk_cmd $oidBase | sed "s/$oidBase.//;s/\"//g")

# go walking and parsing
# take subtree OIDs one by one
for ((cntOIDs=1;cntOIDs<numOIDs;cntOIDs++)); do
    argSubtree=${@:$OPTIND+$cntOIDs:1}
#    echo "argSubtree=$argSubtree"
    # argSubtree is OID? Yes - do various truks
    if  [[ $argSubtree =~ $argRegex ]]; then 
       # Split arg to Macro name and subtree oid
       read macroSubtree oidSubtree <<< $(splitByRegex "$argSubtree" "$argRegex")
       # if no macroName in argument, splitByRegex return only OID in macroSubtree. oidSubtree is null. We need to do macroSubtree -> oidSubtree
       if [ "$oidSubtree" == "" ]; then oidSubtree=$macroSubtree; macroSubtree=; fi
       read macroSubtree <<<  $(makeMacroName $macroSubtree $(($cntOIDs+1)))
       # Save macro name
       arrMacroNames[$cntOIDs]=$macroSubtree
       # read walking result 
       while read snmpData; do
             # split data by regex to index and other part - value
             read snmpIdx snmpValue <<< $(splitByRegex "$snmpData" "$snmpRegex")
             if [ ${arrIndexes[$snmpIdx]} ]; then
                # put value to Values array, pseudo-column N, when N - number of given subtree
                arrValues[$snmpIdx,$cntOIDs]=$snmpValue
             fi
       done < <($snmpwalk_cmd $oidSubtree | sed "s/$oidSubtree.//;s/\"//g;")
    fi
done

# Lets make JSON
# How much snmp indexes we have. Use this number for printing (or not) comma after elements until last.
#numSNMPIndexes=$((${#arrIndexes[*]} - 0))
numSNMPIndexes=$((${#arrIndexes[*]}))
# decrease because 
numMacroNames=$((${#arrMacroNames[*]} - 1))
nCnt=0
#cntIndexes=0
# print header of JSON
printf "{\n\t\"data\":[\n\n"
# Take all stored snmp indexes one by one 
for idxSNMPIndexes in ${arrIndexes[*]}
  do
    ((nCnt++))
    snmpIdx=${arrIndexes[idxSNMPIndexes]}
    printf "\t{  \"{#SNMPINDEX}\":\"%s\", " "$idxSNMPIndexes"
       # get data from pseudo-columes of array and print it
       for idxMacroNames in ${!arrMacroNames[*]}
         do
            printf "\"{#%s}\":\"%s\"" "${arrMacroNames[$idxMacroNames]}" "${arrValues[$idxSNMPIndexes,$idxMacroNames]}"
            # It's last element? No - print comma
            (( idxMacroNames < numMacroNames )) &&  printf ", "
         done
         # It's last section? No - print comma. Else - close curly
         (( nCnt < numSNMPIndexes )) && printf "  },\n" ||  printf "  }"
done
printf "\n\n\t]\n}"
