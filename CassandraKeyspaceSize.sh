#!/bin/bash
#--- We need nrjmx-1.0.1-jar-with-dependencies.jar for this script to load JMX Metrics
if [ -e /home/keyspace.txt ]
then
    rm -rf /home/keyspace.txt
fi

function bytes_to_gb {
    local -i bytes=$1;
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( (bytes + 1023)/1024 ))KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( (bytes + 1048575)/1048576 ))MB"
    elif [[ $bytes -lt 1099511627776 ]]; then
        echo "$(( (bytes + 1073741823)/1073741824 ))GB"
    else
        echo "$(( (bytes + 1099511627775)/1099511627776))TB"

    fi
}
function diskspace {
    Cassandranodes=`nodetool status | grep UN  | awk '{print $2}'|sort`
    for node in $Cassandranodes; do
    df -kh | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | while read output;
    do
    echo $node >> /home/keyspace.txt
    echo $output >>/home/keyspace.txt
    usep=$(echo $output | awk '{ print $1 }' | cut -d'%' -f1 )
    partition=$(echo $output | awk '{ print $2 }' )
    if [ $usep -ge 60 ]; then
        echo "Running out of space on \"$partition ($usep%)\" on $node as on $(date)"  >>/home/keyspace.txt
   fi
done
echo $'\n' >> /home/keyspace.txt
done
}
clustername=`cat /etc/cassandra/conf/cassandra.yaml |grep cluster_name |cut -f2 -d :`
keyspaces=("")
# keyspaces=("")
  for keyspace in "${keyspaces[@]}"; do
    nodes=`nodetool status | grep UN  | awk '{print $2}'|sort`
    let SUMVAL=0
    for node in $nodes; do
    value=`echo "org.apache.cassandra.metrics:type=Keyspace,keyspace=$keyspace,name=TotalDiskSpaceUsed" | java -jar /home/nrjmx-1.0.1-jar-with-dependencies.jar -hostname $node -port 7199 -username cassandra -password cassandra|cut -f4 -d ,|cut -f2 -d :|cut -f1 -d "}"`
        let SUMVAL=$SUMVAL+$value
        #echo $SUMVAL,$value
#echo $SUMVAL
gb="$(bytes_to_gb "$SUMVAL")"
#echo $gb,$keyspace,$clustername >> /home/keyspace.txt
done
echo $gb,$keyspace,$clustername >> /home/keyspace.txt
done
echo $'---------------------------------------------------' >> /home/keyspace.txt
echo $'\n' >> /home/keyspace.txt
diskspace

file=/home/keyspace.txt
mailalert(){
sendmail -F Cassandra -it <<END_MESSAGE
To:email@.com
Subject: Cassandra Keyspace size $clustername

$(cat $file)
END_MESSAGE
}
mailalert
