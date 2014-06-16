#!/bin/sh
set -u
set -x
set -e

CURD=`pwd`

cd /disk1

sysbench --test=fileio --file-num=64 --file-total-size=350G --file-extra-flags=direct prepare
   # pre-run to get card in steady state
sysbench --test=fileio --file-total-size=350G --file-test-mode=rndwr --max-time=3600 --max-requests=100000000 --num-threads=16 --init-rng=on --file-num=64 --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=16384 run
sysbench --test=fileio --file-num=64 --file-total-size=350G cleanup

for sizei in 100 250 300; do
   size=${sizei}G
   cd /disk1
   sysbench --test=fileio --file-num=64 --file-total-size=$size --file-extra-flags=direct prepare
   for mode in rndrd rndwr rndrw; do
   for blksize in 16384 ; do
      for threads in 1 2 4 8 16 32 64; do
         echo "====== testing $blksize in $threads threads"
         echo PARAMS $size $mode $threads $blksize > $CURD/sysbench-size-$size-mode-$mode-threads-$threads-blksz-$blksize
         sysbench --test=fileio --file-total-size=$size --file-test-mode=$mode\
            --max-time=120 --max-requests=100000000 --num-threads=$threads --init-rng=on \
            --file-num=64 --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=$blksize run \
            | tee -a $CURD/sysbench-size-$size-mode-$mode-threads-$threads-blksz-$blksize 2>&1
      done
   done
   done
   sysbench --test=fileio --file-total-size=$size cleanup
   cd $CURD
done
