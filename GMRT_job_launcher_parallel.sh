#!/bin/bash
list=$1

MAX_JOBS=5

# file to record the number of jobs currently running
touch

# restart the number of jobs currently run to 0
#jobs=0

# send the restarted value to log file
echo 0 >

rsync

file=1

while read line
do
	f=`basename $line`
	echo qsub -N gpu_$f -l nodes=1:ppn=8:gpu node_kickstart_parallel $line
	# request 1 node and 8 cores per job
	qsub -o pipeline/logs -e pipeline/logs -N GMRT_GPU_23aug_${file} -l walltime=48:00:00,nodes=1:ppn=8:gpu -v file=$line node_kickstart_parallel

	file=$((file + 1))

done < $list

