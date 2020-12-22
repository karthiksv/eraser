#!/bin/bash

data_file=$1;

macro_list=(`awk '{print $1}' $data_file | awk -F '_' '{print $1}' | grep -v '#' | sort -k1 |uniq`)

for i in ${macro_list[@]}
do 
	awk -v macro="$i" 'BEGIN { 
		bit_sum=0; sw_sum=0;
	} { 
		x=macro "_"; 
		if ((($1==macro) || ($1~x))) {
			bit_sum+=$3; sw_sum+=$3*$4;
		}
	} END{
		if (bit_sum>0)	print macro " " bit_sum " " sw_sum/bit_sum
	} ' $data_file; 
done
