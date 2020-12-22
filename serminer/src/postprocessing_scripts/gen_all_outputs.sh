METRIC=$1
WORKLOAD=$2	#inst-> INST spec->SPEC pv->Power Virus
DD=0
if [ $WORKLOAD = "inst" ]
then
	echo "Single inst workloads"
	SM_OUTDIR="/tmp/STRESSMARK_OUT/DD${DD}"
	INST_OUTDIR="/tmp/VCD_OUT/DD${DD}"
	for i in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.5 0.35 0.4 0.75 0.99
	do
		echo -n "$i "
		if [ $METRIC = "sw" ]
		then
			metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${INST_OUTDIR} ${i} 0 | awk '{print \$NF}'`
		elif [ $METRIC = "cov" ]
		then
			metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${INST_OUTDIR} ${i} 0  | awk '{print \$2}'`
		fi
		echo  "$metric"
	done
	
	echo "SM_TH/RES_TH 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99"
	for i in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99
	do
		echo -n "$i "
		for j in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99
		do
		if [ $METRIC = "sw" ]
		then
			metric=(`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SM_OUTDIR}/SM_TH_${i} $j 0 | tail -n 1 | awk '{print \$NF}'`)
		elif [ $METRIC = "cov" ]
		then
			metric=(`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SM_OUTDIR}/SM_TH_${i} $j 0 | head -n 1 | awk '{print \$2}'`)
		fi
			echo -n "$metric "
		done
		echo ""
	done
elif [ $WORKLOAD = "pv" ]
then
	PV_OUTDIR=/tmp/POWER_VIRUS/
	insts=(`ls $PV_OUTDIR/*_macros.txt | awk -F '[/_]' '{print \$(NF-1)}'`)

	echo "SM_TH 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99"
	for w in "${insts[@]}"
	do
		echo -n "$w "
		for i in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99
		do
			if [ $METRIC = "sw" ]
			then
				metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${PV_OUTDIR}/PV_${w}_macros_TH_${i}/res_th_$i $j 0 | awk '{print \$NF}'`
			elif [ $METRIC = "cov" ]
			then
				metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${PV_OUTDIR}/PV_${w}_TH_macros_${i}/res_th_$i $j 0 | awk '{print \$NF}'`
			fi
			echo -n "$metric "
		done
		echo ""
	done
elif [ $WORKLOAD = "daxpy" ]
then
	DAXPY_OUTDIR=/tmp/VCD_OUT/stressmarks
	echo "0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99"
	for j in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99
	do
		if [ $METRIC = "sw" ]
		then
			metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${DAXPY_OUTDIR} $j 0 | awk '{print \$NF}'`
		elif [ $METRIC = "cov" ]
		then
			metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${DAXPY_OUTDIR} $j 0 | awk '{print \$2}'`
		fi
			echo -n "$metric "
	done

else
	SPEC_OUTDIR=/tmp/VCD_OUT/cpu2017
	SPEC_OUTDIR="/home/karthik/ERASER_LOGS/VCD_OUT/cpu2017_5M"
	SPEC_SM_OUTDIR=/tmp/STRESSMARK_OUT/cpu2017/stressmarks
	j="0.001"
	insts=(`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SPEC_OUTDIR} $j 1 | head -n 1`)

	if [ $METRIC = "cov" ]
	then
		metric=(`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SPEC_OUTDIR} $j 1 | head -n 2 | tail -n 1`)
	elif [ $METRIC = "sw" ]
	then
		metric=(`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SPEC_OUTDIR} $j 1 | head -n 3 | tail -n 1`)
		$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SPEC_OUTDIR} $j 1
	fi

	for (( i=0; i<${#insts[@]}; i++ ))
	do
		echo "${insts[$i]} ${metric[$i]}"
	done
 
	exit       
	echo "${insts[@]}"
	echo "SM_TH 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99"
	for w in "${insts[@]}"
	do
		echo -n "$w "
		for i in 0.001 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.75 0.99
		do
			if [ $METRIC = "sw" ]
			then
				metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SPEC_SM_OUTDIR}/SM_${w}_${i} $j 0 | awk '{print \$NF}'`
			elif [ $METRIC = "cov" ]
			then
				metric=`$ERASER_HOME/serminer/src/postprocessing_scripts/find_thresholded_max.sh wted_sw ${SPEC_SM_OUTDIR}/SM_${w}_${i} $j 0 | awk '{print \$2}'`
			fi
				echo -n "$metric "
		done
		echo ""
	done
fi
