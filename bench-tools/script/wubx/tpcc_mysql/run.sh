./tpcc_load 192.168.143.171:5617 tpcc100 admin admin 100 >> 1.out 
sleep 120
for i in `seq 1 3`; do ./thdp_run.sh;sleep 100; done
