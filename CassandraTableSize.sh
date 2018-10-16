#!/bin/sh
#--- We need nrjmx-1.0.1-jar-with-dependencies.jar for this script to load JMX Metrics
if [ "$1" != "" ]; then
    echo "for keyspace $1 "
else
    echo "Positional parameter 1 is empty"
fi

if [ "$2" != "" ]; then
    echo "for table $2 "
else
    echo "Positional parameter 1 is empty"
fi

if [ -e /home/table.txt ]
then
    rm -rf /home/table.txt
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

clustername=`cat /etc/cassandra/conf/cassandra.yaml |grep cluster_name |cut -f2 -d :`
keyspaces=("$1")
table=("$2")
  for keyspace in "${keyspaces[@]}"; do
    nodes=`nodetool status | grep UN  | awk '{print $2}'|sort`
    let SUMVAL=0
    for node in $nodes; do
    value=`echo "org.apache.cassandra.metrics:type=Table,keyspace=$keyspace,scope=$table,name=TotalDiskSpaceUsed" | java -jar /home/nrjmx-1.0.1-jar-with-dependencies.jar -hostname $node -port 7199 -username cassandra -password cassandra|cut -f5 -d ,|cut -f2 -d :|cut -f1 -d "}"`
        let SUMVAL=$SUMVAL+$value
        #echo $SUMVAL,$value
#echo $SUMVAL
gb="$(bytes_to_gb "$SUMVAL")"
#echo $gb,$keyspace,$clustername >> /home/table.txt
done
echo $gb,$keyspace,$table,$clustername >> /home/table.txt
done
echo $'---------------------------------------------------' >> /home/table.txt
echo $'\n' >> /home/table.txt
#diskspace

file=/home/table.txt
mailalert(){
/sbin/sendmail -F Cassandra -it <<END_MESSAGE
To: xxxx
Subject: Cassandra table size $clustername

$(cat $file)
END_MESSAGE
}
mailalert
