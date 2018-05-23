#!/bin/bash
dgo='/usr/local/go/bin/go'
PROCESSES=3

CLUSTERSTRING=""

killall -9 etcd
killall scheduler

if [ $1 == "-k" ];then
    exit
fi


for i in $(seq 1 $PROCESSES)
do
    #port and ip for etcd
    CLUSTERSTRING=$CLUSTERSTRING"infra"`expr $i - 1`"=http://127.0.0."$i":2380,"
done


#do i need to alloc the shared memory here?

echo INSTALLING THE SCHEDULER
$dgo install github.com/wantonsolutions/dara/scheduler



dd if=/dev/zero of=./DaraSharedMem bs=400M count=1
chmod 777 DaraSharedMem
exec 666<> ./DaraSharedMem



#$1 is either -w (record) or -r (replay)

scheduler $1 1> s.out 2> s.out &
#gnome-terminal -e 'bash -c "ls; sleep 3"'
#gnome-terminal --execute 'echo dog'
#gnome-terminal -e 'bash -c "scheduler -r; sleep 5"'
#gnome-terminal -e 'bash -c "python"'
sleep 2





#kill any old clusters
fuser -k 2380/tcp
#remove old databases
rm -r *[0-9].etcd
# install dara etcd
echo Building Dara Etcd
rm ./bin/etcd
../dgobuild
echo DONE BUILDING
##Turn on dara
export GOMAXPROCS=1
export DARAON=true


#itterativly launch the cluster
for i in $(seq 1 $PROCESSES)
do
    export DARAPID=$i
    infra="infra"`expr $i - 1`
    #Setup assert names, each node is given an ip port 127.0.0.(id):12000
    #launch the nodes
    $TERMINAL ./bin/etcd --name $infra --initial-advertise-peer-urls http://127.0.0.$i:2380 \
      --listen-peer-urls http://127.0.0.$i:2380 \
      --listen-client-urls http://127.0.0.$i:2379,http://127.0.0.$i:2379 \
      --advertise-client-urls http://127.0.0.$i:2379 \
      --initial-cluster-token etcd-cluster-1 \
      --initial-cluster $CLUSTERSTRING \
      --initial-cluster-state new 1>etcd$i.log &
done
