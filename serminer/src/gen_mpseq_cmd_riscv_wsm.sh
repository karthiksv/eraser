#!/usr/bin/env bash
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

set -e

RUN=1
DEBUG=1
WEIGHTED=1

#Set Python version
PYTHON="python3"
if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <STRESSMARK_TYPE 0: SER  1: Aging> <SERMINER_OUTPUT_DIR> <STRESSMARK_OUT_DIR> <RESIDENCY_THRESHOLD> <NUM_PERMUTATIONS> <DEPENDENCY DISTANCE> <Instruction fraction (optional... for aging stressmark>" >&2
    exit 1
fi

SERMINER_OUTPUT_DIR=$1
STRESSMARK_OUT_DIR=$2
RES_THRESHOLD=$3
NUM_PERMUTATIONS=$4
DEP_DISTANCE=$5
WORKLOAD_INST_LIST=$6

if [ x${INST_FRACTION}x = "xx" ]
then
	INST_FRACTION=0.99
	echo "Setting default inst fraction"
fi

# Check if results directory exists
if [ -d "$SERMINER_OUTPUT_DIR" ] && [ -e "${SERMINER_CONFIG_HOME}/inst_list.txt" ]
then
    if [ $DEBUG -eq 1 ]
    then
        echo "Verifying $SERMINER_OUTPUT_DIR exists"
    fi
else
    echo "SERMiner output directory $SERMINER_OUTPUT_DIR or instruction list ${SERMINER_CONFIG_HOME}/inst_list.txt not present. Exiting..."
    exit 1
fi

NUM_INSTS=$(wc -l "${SERMINER_CONFIG_HOME}/inst_list.txt" | awk '{print $1}')
BMNAME=`basename ${WORKLOAD_INST_LIST%_inst_list*}`
echo $BMNAME

# Create STRESSMARK_OUT_DIR 
mkdir -p "$STRESSMARK_OUT_DIR"

if [ $DEBUG -eq 1 ]
then
    echo "Dictionary size = $NUM_INSTS"
fi

if [ $DEBUG -eq 1 ]
then
    echo "$PYTHON $SERMINER_HOME/src/gen_aging_stressmark_riscv.py -o $SERMINER_OUTPUT_DIR -n $NUM_INSTS -th $RES_THRESHOLD -p 0 -t wted_sw -il $WORKLOAD_INST_LIST | tail -n 1 "
fi

if [ $RUN -eq 1 ]
then
	stressmark_insts_list=( $($PYTHON "$SERMINER_HOME/src/gen_aging_stressmark_riscv.py" -o "$SERMINER_OUTPUT_DIR" -n "$NUM_INSTS" -th "$RES_THRESHOLD" -p 0 -t wted_sw -il "$WORKLOAD_INST_LIST" | tail -n 1 ) )
fi

if [ $DEBUG -eq 1 ]
then
    echo "Insts list: $stressmark_insts_list"
fi

if  [ $WEIGHTED -eq 1 ]
then
    inst_weights=( $($PYTHON "$SERMINER_HOME/src/gen_aging_stressmark_riscv.py" -o "${SERMINER_OUTPUT_DIR}" -n "$NUM_INSTS" -th "$RES_THRESHOLD" -p 1 -t wted_sw -if "$INST_FRACTION"  -il "$WORKLOAD_INST_LIST" | tail -n 1 ) )
else
    for (( i=0; i<${#stressmark_insts_list[@]}; i++ ))
    do
        inst_weights[$i]=1
    done
fi

k=0

for (( i=0; i<${#stressmark_insts_list[@]}; i++ ))
do
    echo "W: ${inst_weights[$i]}"
    for (( j=0; j<${inst_weights[$i]}; j++ ))
    do
        weighted_stressmark_insts_list[$k]=${stressmark_insts_list[$i]}
        k=$((k+1))
    done
done

num_insts=${#weighted_stressmark_insts_list[@]}
echo "Inst weights: ${inst_weights[0]} ${inst_weights[1]}"
echo "Weighted insts: ${weighted_stressmark_insts_list[*]}"

echo "python $MICROPROBE_HOME/targets/riscv/examples/riscv_ipc_seq.py --dependency-distances $DEP_DISTANCE --loop-size 10000 --instructions ${weighted_stressmark_insts_list[*]} --output-dir $STRESSMARK_OUT_DIR --num_permutations $NUM_PERMUTATIONS --microbenchmark_name SM_${BMNAME}_TH_${RES_THRESHOLD}"
