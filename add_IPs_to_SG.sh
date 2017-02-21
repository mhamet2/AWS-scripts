#!/bin/bash

SCRIPT=`dirname $0`/`basename $0 .sh`
CONFIG=$SCRIPT.config


if [ ! -f "$CONFIG" ]; then
        echo "No configuration file found"
        exit 1
fi

PROFILE=`cat $CONFIG | grep -v '\#' | grep PROFILE | sed 's/PROFILE=\(.*\)/\1/'`
SG=`cat $CONFIG | grep -v '\#' | grep SG | sed 's/SG=\(.*\)/\1/'`
URL=`cat $CONFIG | grep -v '\#' | grep URL | sed 's/URL=\(.*\)/\1/'`


oldIPs=`aws --profile $PROFILE ec2 describe-security-groups --filters Name=group-name,Values=$SG --query 'SecurityGroups[*].IpPermissions[*].IpRanges[*].CidrIp' --output text | tr "\t" "\n" | sort | uniq`
newIPs=$(dig $URL +short)

#for address in $oldIPs
# do
   echo "$newIPs"
# done

