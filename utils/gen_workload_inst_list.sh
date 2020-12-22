#!/bin/bash


#input_file="/tmp/VCD_FILES/cpu2017/deepsjeng.log"
input_file=$1
INPUT_TYPE=$2

if [ $INPUT_TYPE = "emulator" ]
then
	echo "Emulator"
	awk '{
		for (i=1; i<=NF; i++) 
			if ($i~/inst/) { 
				inst=toupper($(i+1)) "_V0"; 
				inst_name[inst]=inst; 
				inst_ct[inst]++;
			}
	}END {
		for (arr in inst_name) 
			print arr " " inst_ct[arr]
	}' $input_file
else
	echo "Spike"
	awk '{
		for (i=1; i<=3; i++) 
			if ($i~/0:/) { 
                inst=toupper($(i+3)) "_V0"; 
                inst_name[inst]=inst; 
                inst_ct[inst]++;
            }
	}END {
		for (arr in inst_name) 
			print arr " " inst_ct[arr]
	}' $input_file
	
fi
