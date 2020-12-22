# Copyright 2020 IBM Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/bin/env sh
RUN=1
DD=0

echo "--------------- Check ERASER environment ---------------"
echo ""
source eraser_setenv
echo ""
echo "--------------- Generate single instruction testcases ---------------"
echo ""
echo "cd $ERASER_HOME/testcases && ./run_all_inst_testcases.sh $DD"
echo ""

if [ $RUN -eq 1 ]
then
	cd $ERASER_HOME/testcases && ./run_all_inst_testcases.sh $DD
fi
echo ""
echo "--------------- Compile single instruction testcases ---------------"
echo ""
echo "cd $ERASER_HOME/testcases/bin && make src_dir=$ERASER_HOME/testcases/src"
echo ""
if [ $RUN -eq 1 ]
then
	cd $ERASER_HOME/testcases/bin && make src_dir=$ERASER_HOME/testcases/src	
fi

echo ""
echo "Compiled all testcases"

#VCD_FILES_DIR=/tmp/VCD_FILES/DD${DD}
VCD_FILES_DIR=/home/karthik/ERASER_LOGS/VCD_FILES/DD${DD}
echo ""
echo "--------------- Running RTL simulations using Rocketchip emulator ---------------"
echo ""
echo "mkdir -p $VCD_FILES_DIR "
echo ""

if [ $RUN -eq 1 ]
then
	mkdir -p $VCD_FILES_DIR
	for INST in $(cat $SERMINER_CONFIG_HOME/inst_list.txt); do
	   echo "$ROCKETCHIP_HOME/emulator/emulator-freechips.rocketchip.system-DefaultConfig-debug --dump-start=1000000 --max-cycles=1010000 -c -v /tmp/VCD_FILES/${INST}_${DD}.vcd $ERASER_HOME/testcases/bin/riscv_ipc-p-${INST}_${DD} "
	   $ROCKETCHIP_HOME/emulator/emulator-freechips.rocketchip.system-DefaultConfig-debug --dump-start=1000000 --max-cycles=1010000 -c -v /tmp/VCD_FILES/${INST}_${DD}.vcd $ERASER_HOME/testcases/bin/riscv_ipc-p-${INST}_${DD} | grep -v "FAILED"
	done;
fi
 
STATS_DIR="/tmp/VCD_STATS/DD${DD}"
mkdir -p $STATS_DIR
echo ""
echo "--------------- Parsing VCD files ---------------"
echo ""

echo "mkdir -p /tmp/STRESSMARK_OUT/stressmark_stats "
echo "for inst in \$(cat $SERMINER_CONFIG_HOME/inst_list.txt); do "
echo "$ERASER_HOME/utils/vcdstats --activities $VCD_FILES_DIR/\${inst}_${DD}.vcd > $STATS_DIR/\${inst}.stats "
echo "done";

if [ $RUN -eq 1 ]
then
	 for inst in $(cat $SERMINER_CONFIG_HOME/inst_list.txt); do
	  echo $inst
	  $ERASER_HOME/utils/vcdstats --activities $VCD_FILES_DIR/${inst}_${DD}.vcd > $STATS_DIR/${inst}.stats 
	done;
fi
sleep 2

echo "--------------- Estimate latch/macro vulnerability ---------------"

VCD_OUT_DIR="/tmp/VCD_OUT/DD${DD}"
for RES_TH in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99 #0.001 0.25 0.5 0.75 0.99
do
	echo "perl $SERMINER_HOME/src/gen_latch_macro_ranking_riscv.pl $STATS_DIR $VCD_OUT_DIR $RES_TH "

	if [ $RUN -eq 1 ]
	then
		perl $SERMINER_HOME/src/gen_latch_macro_ranking_riscv.pl $STATS_DIR  $VCD_OUT_DIR $RES_TH 
	fi

	echo "Generated macro stats in $VCD_OUT_DIR/th_${RES_TH}"

	echo "--------------- Generate stressmarks ---------------"
	#Change 1st arg to 0 for SER stressmarks
	echo "$SERMINER_HOME/src/gen_mpseq_cmd_riscv.sh 1 /tmp/VCD_OUT/res_th_${RES_TH} /tmp/VCD_OUT/stressmarks $RES_TH 5 $DD" 
	mp_cmd=`${SERMINER_HOME}/src/gen_mpseq_cmd_riscv.sh 1 /tmp/VCD_OUT/res_th_${RES_TH} /tmp/VCD_OUT/stressmarks $RES_TH 5 $DD | tail -n 1`
	echo "Running Microprobe command"
	echo "cd $MICROPROBE_HOME/targets/riscv/examples && $mp_cmd"
	if [ $RUN -eq 1 ]
	then
		cd $MICROPROBE_HOME/targets/riscv/examples
		$mp_cmd
		echo "Generating microbenchmarks named:"
		echo "['SM_TH_${RES_TH}_DD${DD}_0', 'SM_TH_${RES_TH}_DD${DD}_1', 'SM_TH_${RES_TH}_DD${DD}_2', 'SM_TH_${RES_TH}_DD${DD}_3', 'SM_TH_${RES_TH}_DD${DD}_4']"
	fi
done


