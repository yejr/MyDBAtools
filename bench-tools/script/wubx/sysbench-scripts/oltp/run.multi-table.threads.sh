#!/bin/sh
set -u
set -x
set -e

ulimit -n 60000

DR="/mnt/raid10"
BD="/mnt/x25e/sysb.80m"

export LD_LIBRARY_PATH=/usr/local/mysql/lib/ 

WT=300
RT=200

ROWS=100000000


log2="/data/log/"
#log2="$DR/"

# restore from backup


function waitm {

while [ true ]
do

mysql -e "set global innodb_max_dirty_pages_pct=0" sbtest

wt=`mysql -e "SHOW ENGINE INNODB STATUS\G" | grep "Modified db pages" | sort -u | awk '{print $4}'`
if [[ "$wt" -lt 100 ]] ;
then
mysql -e "set global innodb_max_dirty_pages_pct=90" sbtest
break
fi

echo "mysql pages $wt"
sleep 10
done

}

# Determine run number for selecting an output directory
RUN_NUMBER=-1

if [ -f ".run_number" ]; then
  read RUN_NUMBER < .run_number
fi

if [ $RUN_NUMBER -eq -1 ]; then
        RUN_NUMBER=0
fi

OUTDIR=res$RUN_NUMBER
mkdir -p $OUTDIR

RUN_NUMBER=`expr $RUN_NUMBER + 1`
echo $RUN_NUMBER > .run_number

#taskset -pc 0-23 `pidof mysqld`
taskset -pc 0-47 `pidof mysqld`
for i in `seq 1 48` ; do mysql -e "select avg(c) from sbtest$i /* FORCE KEY primary */; " sbtest ; done

#for thread in 2048
for thread in 1 2 4 8 16 24 32 48 64 128 256 512 1024 
#for thread in 24 
do

#mysql -e "select avg(id) from sbtest;" sbtest


./sysbench --test=db/oltp.lua  --oltp_tables_count=48 --oltp-table-size=5000000 --rand-init=on  --num-threads=$thread --oltp-read-only=on --report-interval=10 --oltp-dist-type=uniform --mysql-socket=/var/lib/mysql/mysql.sock --max-time=$WT --max-requests=0 run | tee -a $OUTDIR/sysbench.$thread.res

sleep 30

for j in 1 
do
echo "$j"
iostat -dx 10 $(($RT/10+1))  >> $OUTDIR/iostat.$thread.res &
dstat -t -v --nocolor --output $OUTDIR/dstat.$thread.res 10 $(($RT/10+1)) > $OUTDIR/dstat_plain.$thread.res  &

./sysbench --test=db/oltp.lua  --oltp_tables_count=48 --oltp-table-size=5000000 --rand-init=on  --num-threads=$thread --oltp-read-only=on --report-interval=10 --oltp-dist-type=uniform --mysql-socket=/var/lib/mysql/mysql.sock --max-time=$RT --max-requests=0 run | tee -a $OUTDIR/sysbench.$thread.res

sleep 30
done



done
