#!/bin/bash

proc=$1

num=1

while read line
do

	echo "Processing file $line "

	qsub -o logs/ofiles -e logs/efiles -N REPROC_23AUG_${num} -l walltime=48:00:00,nodes=1:ppn=8:gpu -v file=$line post_processing_parallel_perf.sh

	num=$((num + 1))

done < $proc
