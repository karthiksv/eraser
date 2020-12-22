#!/bin/bash

OUT_DIR=$1

awk 'BEGIN{i=0}
     NR==FNR { 
	if ($1!~/#/) {
		name[i]=$1; 
		bw[i]=$2; 
		i++; 
	}
	else {
		start_str=$0;
	}
}
{ 
	if($1!~/#/) { 
		sw[$1]=$4; 
		res[$1]=$5;
		if (max_sw[$1]<$4) { 
			max_sw[$1]=sw[$1]; 
		}
		if (max_res[$1]<$5) { 
			max_res[$1] = res[$1]
		}
	}
} END {
	print start_str; 
	for (i=0; i<FNR; i++) 
		print name[i] " " bw[i] " " max_sw[name[i]] " " max_res[name[i]];
}' $OUT_DIR/*macro_data.txt
