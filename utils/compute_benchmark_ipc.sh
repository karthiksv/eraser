#!/bin/bash

#Compute benchmark IPC from Rocket chip emulator trace
BIN_DIR=$ERASER_HOME/testcases/bin
EMULATOR_DIR=$ROCKETCHIP_HOME/emulator
SPIKE_HOME=/home/karthik/github_installs/chipyard/toolchains/riscv-tools/riscv-isa-sim/build/
WARMUP_INSTS=700000
SLEEP_TIME=120

for i in `ls ${BIN_DIR}/riscv_ipc-p-*V0_0`
#for i in `ls ${BIN_DIR}/riscv_ipc-p-ADDIW_V0*`
do
	BENCHMARK=`echo $i | awk -F '-p-' '{print \$NF}' | awk -F '_V0' '{print tolower(\$1)}'`
	BM_TRACEFILE=/tmp/${BENCHMARK}.trace
	$EMULATOR_DIR/emulator-freechips.rocketchip.system-DefaultConfig +verbose $i 2>&1 | $SPIKE_HOME/spike-dasm > $BM_TRACEFILE &
	pid=$!
	#echo $pid
	sleep $SLEEP_TIME
	kill -9 $pid
	#echo "Killed $pid, finished running $BENCHMARK"
	echo -n "$BENCHMARK "
	tail -n +${WARMUP_INSTS} $BM_TRACEFILE | grep $BENCHMARK | awk -F 'inst' '
		BEGIN{
			i=0; inst=1
		}
		{
			line[i]=$2; 
			if (NR>1 && line[i]!=line[i-1]) { 
				inst++;
			} 
			i++;
		}
		END { 
			print i/inst
		}'
done
