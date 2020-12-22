#!/bin/bash
SUITE=$1
WORKLOAD=$2
SM=$3	#SM=0 - baseline SM=1 stressmark


TOT_CT=5;
DD=0;
NUM_COMPONENTS=18

if [ $SUITE = "inst" ]
then
	SM_OUTDIR="/tmp/STRESSMARK_OUT/DD${DD}"
	for i in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.5 0.35 0.4 0.75 0.99
	do
		./macro_sw_profile.sh $SM_OUTDIR/SM_TH_${i}/SM_TH_${i}_DD0_${ct}_macro_data.txt| sort -rnk2 -rnk3	
	done
elif [ $SUITE = "pv" ]
then
	PV_OUTDIR="/tmp/POWER_VIRUS_NONWTED/"
	max_sw=0
	max_ct=0
	max_th=0

	for i in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 #0.5 0.35 0.4 0.75 0.99
	do
		for (( ct=0; ct<$TOT_CT; ct++ ))
		do
			if [ -e $PV_OUTDIR/PV_${WORKLOAD}_macros_TH_${i}/PV_${WORKLOAD}_macros_TH_${i}_DD0_${ct}_macro_data.txt ]
			then
				tot_sw=`./macro_sw_profile.sh $PV_OUTDIR/PV_${WORKLOAD}_macros_TH_${i}/PV_${WORKLOAD}_macros_TH_${i}_DD0_${ct}_macro_data.txt| sort -rnk3 -k1 | head -n $NUM_COMPONENTS | awk '{sum+=\$3*\$4}END{print sum}'`;
				if [ `echo $tot_sw $max_sw | awk '{if (\$1 > \$2) print 0; else print 1}'` -eq 0 ]
				then
					max_sw=$tot_sw
					max_ct=$ct
					max_th=$i
				fi
				#echo "$i $tot_sw"
			fi
		done
	done

	echo "SM_$WORKLOAD $max_ct $max_sw $max_th"
	#./macro_sw_profile.sh $SPEC_SM_OUTDIR/SM_${WORKLOAD}_${max_th}/SM_${WORKLOAD}_TH_${max_th}_DD0_${max_ct}_macro_data.txt| sort -rnk2 -k1| head -n $NUM_COMPONENTS
	#echo "./macro_sw_profile.sh $PV_OUTDIR/PV_${WORKLOAD}_macros_TH_${max_th}/PV_${WORKLOAD}_macros_TH_${max_th}_DD0_${max_ct}_macro_data.txt| sort -rnk3 -k1| head -n $NUM_COMPONENTS"
	./macro_sw_profile.sh $PV_OUTDIR/PV_${WORKLOAD}_macros_TH_${max_th}/PV_${WORKLOAD}_macros_TH_${max_th}_DD0_${max_ct}_macro_data.txt| sort -rnk3 -k1| head -n $NUM_COMPONENTS 
		
	echo ""

else
	SPEC_OUTDIR=/tmp/VCD_OUT/cpu2017
	SPEC_SM_OUTDIR=/tmp/STRESSMARK_OUT/cpu2017/stressmarks/DD${DD}
	max_sw=0
	max_ct=0
	max_th=0

	if [ $SM -eq 0 ]
	then
		tot_sw=`./macro_sw_profile.sh $SPEC_OUTDIR/${WORKLOAD}_macro_data.txt | sort -rnk3 -k1 | head -n $NUM_COMPONENTS | awk '{sum+=\$3*\$4}END{print sum}'`
		echo "$WORKLOAD $tot_sw"
		./macro_sw_profile.sh $SPEC_OUTDIR/${WORKLOAD}_macro_data.txt | sort -rnk3 -k1 | head -n $NUM_COMPONENTS
	else
		#for i in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 #0.5 0.35 0.4 0.75 0.99
		for i in 0.99 #0.001 0.05 0.1 0.15 0.2 0.99 #0.5 0.35 0.4 0.75 0.99
		do
			for (( ct=0; ct<$TOT_CT; ct++ ))
			do
				tot_sw=`./macro_sw_profile.sh $SPEC_SM_OUTDIR/SM_${WORKLOAD}_${i}/SM_${WORKLOAD}_TH_${i}_DD0_${ct}_macro_data.txt| sort -rnk3 -k1 | head -n $NUM_COMPONENTS | awk '{sum+=\$3*\$4}END{print sum}'`;
				if [ `echo $tot_sw $max_sw | awk '{if (\$1 > \$2) print 0; else print 1}'` -eq 0 ]
				then
					max_sw=$tot_sw
					max_ct=$ct
					max_th=$i
				fi
			done
		done

		echo "SM_$WORKLOAD $max_ct $max_sw $max_th"
		#./macro_sw_profile.sh $SPEC_SM_OUTDIR/SM_${WORKLOAD}_${max_th}/SM_${WORKLOAD}_TH_${max_th}_DD0_${max_ct}_macro_data.txt| sort -rnk2 -k1| head -n $NUM_COMPONENTS
		./macro_sw_profile.sh $SPEC_SM_OUTDIR/SM_${WORKLOAD}_${max_th}/SM_${WORKLOAD}_TH_${max_th}_DD0_${max_ct}_macro_data.txt| sort -rnk3 -k1| head -n $NUM_COMPONENTS | awk '{print $NF}'
	fi
		
	echo ""
fi
