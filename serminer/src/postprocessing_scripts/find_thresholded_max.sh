#!/bin/bash

METRIC=$1
OUTDIR=$2
RES_TH=$3
VERBOSE=$4
#RES_TH=0

INST_LIST=(`ls $OUTDIR/*macro_data.txt | awk -F '/' '{print \$NF}'| awk -F '_macro' '{print \$1}'`)
#echo "${INST_LIST[*]}"
#echo "perl $SERMINER_HOME/src/gen_thresholded_data.pl $METRIC $OUTDIR $RES_TH"

OUT_SW_ALL=(`perl $SERMINER_HOME/src/gen_thresholded_data.pl $METRIC $OUTDIR $RES_TH | awk -v metric="$METRIC" '{
	for (i=3;i<=NF;i++) 
		if (metric=="sw")
			inst_metric[i]+=$i;	#Non weighted
		else
			inst_metric[i]+=$2*$i;
	tot_bits+=$2
	} END {
		for (i=3;i<=NF;i++) 
		if (metric=="sw")
			print (inst_metric[i]/NR " ")
		else
			print (inst_metric[i]/tot_bits " ")
	}'`)

#OUT_SW_MAX=(`perl $SERMINER_HOME/src/gen_thresholded_data.pl $METRIC $OUTDIR $RES_TH | awk -v metric="$METRIC" '{
#	for (i=3;i<=NF;i++) 
#		if (metric=="sw")
#			inst_metric[i]+=$i;	#Non weighted
#		else
#			inst_metric[i]+=$2*$i;
#	tot_bits+=$2;
#	} END { 
#		maxval=0; 
#		for (i=3;i<=NF;i++) 
#			if (inst_metric[i]>maxval) {
#				maxval=inst_metric[i]; 
#				max_index=i-2;  
#			}
#		if (metric=="sw")
#			print (maxval/NR " " max_index)
#		else
#			print (maxval/tot_bits " " max_index)
#	}'`)

OUT_SW_MAX=(`echo ${OUT_SW_ALL[*]} ${INST_LIST[*]} | awk 'BEGIN{max=0; max_ind=""} {for (i=1;i<=NF/2;i++) if(max<$i){ max=$i; max_ind=$(i+NF/2)}}END{print max " " max_ind}'`)
OUT_SW_AVG=`IFS=$'\n'; echo ${OUT_SW_ALL[*]} | awk '{sum+=$1}END{print sum/NR}'`
# OUT_SW_AVG=`perl $SERMINER_HOME/src/gen_thresholded_data.pl $METRIC $OUTDIR $RES_TH | awk -v metric="$METRIC" '{
# 	for (i=3;i<=NF;i++) 
# 		if (metric=="sw")
# 			inst_metric[i]+=$i;	#Non weighted
# 		else
# 			inst_metric[i]+=$2*$i;
# 	tot_bits+=$2
# 	} END { 
# 		tot_metric=0; 
# 		for (i=3;i<=NF;i++) 
# 			tot_metric += inst_metric[i]; 
# 		if (metric=="sw")
# 			print (tot_metric/NF/NR)
# 		else
# 			print (tot_metric/NF/tot_bits)
# 	}'`

OUT_COV_ALL=(`awk '{for (i=2;i<=NF; i++) {macros[i]+=\$i;}}END{ for (j=2;j<=NF;j++) print macros[j]}' $OUTDIR/res_th_${RES_TH}/macro_perinst_coverage_th${RES_TH}.txt`)
OUT_COV_MAX=(`echo ${OUT_COV_ALL[*]} ${INST_LIST[*]} | awk 'BEGIN{max=0; max_ind=""} {for (i=1;i<=NF/2;i++) if(max<$i){ max=$i; max_ind=$(i+NF/2)}}END{print max " " max_ind}'`)
#OUT_ALL=(`echo "${OUT_COV_ALL[*]} ${OUT_SW_ALL[*]}" | awk 'BEGIN{max_cov=0; max_metric=0}{for (i=1; i<=NF/2; i++) {cov=$i; metric = $i*$(i+NF/2); if (max_cov<cov) { max_cov=cov; cov_index=i}; if (max_metric<metric){ max_metric=metric; metric_index=i}}; print max_cov " " max_metric " " $cov_index*$(cov_index+NF/2) " " $metric_index}'`)

if [ $VERBOSE -eq 1 ]
then
	echo "${INST_LIST[*]}"
	echo "${OUT_COV_ALL[*]}"
	echo "${OUT_SW_ALL[*]}"
fi
#echo "${OUT_MAX[0]} ${OUT_MAX[1]} $OUT_SW_AVG"
MAX_COV_VAL=${OUT_COV_MAX[0]}
MAX_COV_INST=${OUT_COV_MAX[1]}

MAX_SW_VAL=${OUT_SW_MAX[0]}
MAX_SW_INST=${OUT_SW_MAX[1]}

echo "$MAX_COV_INST $MAX_COV_VAL $MAX_SW_INST $MAX_SW_VAL" 
