#!/bin/bash

data_file=$1;

#macro_list=(`awk '{print $1}' $data_file | awk -F '_' '{if($1=="io") print $1 "_" $2; else print $1}' | grep -v '#' | sort -k1 |uniq`)
macro_list=(`awk '{print \$1}' $data_file | awk -F '_' '{if(\$1=="io") print \$1 "_" \$2; else print \$1}' | grep -v '#' | sort -k1 |uniq`)

for i in ${macro_list[@]}
do 
	awk -v macro="$i" 'BEGIN { 
		bit_sum=0; sw_sum=0;
	} { 
		x=macro "_"; 
		if(macro~"io_") {
			m_str=$1 "_" $2 
		}
		else {
			m_str=$1;
		}
		if (((m_str==macro) || (m_str~x))) {
			macro_sum+=$2; bit_sum+=$3; sw_sum+=$3*$4;
		}
	} END{
		if (bit_sum>0)	print macro " " macro_sum " " bit_sum " " sw_sum/bit_sum
	} ' $data_file; 
done
