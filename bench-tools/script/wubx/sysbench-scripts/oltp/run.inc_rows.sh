#!/bin/sh
set -u
set -x
set -e

DR="/mnt/raid10"
BD="/mnt/x25e/sysb.80m"

export LD_LIBRARY_PATH=/usr/local/mysql/lib/mysql/

WT=600
RT=180

ROWS=100000000

EXPER="L2 ro"

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


for thread in `seq 1 2 25`
do

ROWS=${thread}000000

#mysql -e "select avg(id) from sbtest;" sbtest

echo "sysbench $EXPER bp ${thread} warmup" >> $OUTDIR/bench.log

./sysbench --test=tests/db/oltp.lua --oltp-tables-count=16 --oltp-table-size=$ROWS --oltp-read-only=on --rand-init=on --num-threads=16 --max-requests=0 --rand-type=uniform --max-time=$WT  --mysql-user=root  run
echo "sysbench $EXPER bp ${thread} warmup END" >> $OUTDIR/bench.log

sleep 30

mysqladmin variables >>  $OUTDIR/mysql_variables.res

for j in 1 2 3
do
echo "$j"
echo "sysbench $EXPER bp ${thread} run $j" >> $OUTDIR/bench.log

iostat -dx 10 $(($RT/10+1)) >> $OUTDIR/oltp.bp$thread.iostat.res &
vmstat  10 $(($RT/10+1))  >> $OUTDIR/oltp.bp$thread.vmstat.res &


./sysbench --test=tests/db/oltp.lua --oltp-tables-count=16 --oltp-table-size=$ROWS --oltp-read-only=on --rand-init=on --num-threads=16 --max-requests=0 --rand-type=uniform --max-time=$RT  --mysql-user=root run | tee -a $OUTDIR/oltp.thread$thread.res

echo "sysbench $EXPER bp ${thread} run $j END" >> $OUTDIR/bench.log

sleep 30
done



done
