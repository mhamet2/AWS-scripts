#!/bin/bash

PATH="/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
SCRIPT=`dirname $0`/`basename $0 .sh`

if [ -z "$1" ]; then
  CONFIG=$SCRIPT.config
else
  CONFIG=$1
fi

if [ ! -f "$CONFIG" ]; then
        echo "No configuration file found"
        exit 1
fi

PROFILE=`cat $CONFIG | grep -v '\#' | grep PROFILE | sed 's/PROFILE=\(.*\)/\1/'`
SG=`cat $CONFIG | grep -v '\#' | grep SG | sed 's/SG=\(.*\)/\1/'`
URL=`cat $CONFIG | grep -v '\#' | grep URL | sed 's/URL=\(.*\)/\1/'`
destdir=`cat $CONFIG | grep -v '\#' | grep stats | sed 's/stats=\(.*\)/\1/'`
VPC=`cat $CONFIG | grep -v '\#' | grep VPC | sed 's/VPC=\(.*\)/\1/'`

NS=$(dig +nocmd +multiline +noall +answer NS $(echo $URL | awk -F'.' {'print$2"."$3'}) | head -n1 | awk {'print$5'})
query=`dig +nocmd +multiline +noall +answer $URL @$NS`
md5=`echo $query | md5sum | awk '{print$1}'`

if [ ! -d "$destdir" ] ; then
    echo "$destdir does not exist"
    exit 1
fi

if [ ! -f "$destdir/$URL.lastmd5" ]; then
    echo "starting..." > $destdir/$URL.lastmd5
    #exit 1
fi

if [ ! -s "$destdir/$URL.lastmd5" ]; then
    exit 1
fi

if grep -c --quiet $md5 $destdir/$URL.lastmd5; then
   echo "No changes on query, nothing to do"
   exit 1
else

  oldIPs=`aws --profile $PROFILE ec2 describe-security-groups --filters Name=group-name,Values=$SG --query 'SecurityGroups[*].IpPermissions[*].IpRanges[*].CidrIp' --output text | tr "\t" "\n" | sort | uniq`
  if [ $? -ne 0 ]; then
    exit 1
  fi
  IFS=$'\n'
  for ip in $oldIPs
    do
      aws --profile $PROFILE ec2 revoke-security-group-ingress --group-id $SG --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80,"IpRanges": [{"CidrIp": "'$ip'"}]}]'
      aws --profile $PROFILE ec2 revoke-security-group-ingress --group-id $SG --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443,"IpRanges": [{"CidrIp": "'$ip'"}]}]'
    done
  for ip in $query
    do
      ip=`echo $ip | awk '{print $5}'`
      aws --profile $PROFILE ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 80 --cidr $ip/32
      aws --profile $PROFILE ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 443 --cidr $ip/32
    done
  echo `echo $md5 > $destdir/$URL.lastmd5`
fi
