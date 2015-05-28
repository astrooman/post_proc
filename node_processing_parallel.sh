#!/bin/bash
# version of node processing script with crude locking mechanism implemented

# lock_file_prep - used to lock rsync filterbank and zerodm execution
# lock_gpu - used to lock specific GPUs
# lock_bifrost - lock Bifrost execution and subsequent moving/cleaning operations
# lock_job_save - lock saving the number of jobs executed

export OMP_NUM_THREADS=8

scriptdir=

work_dir=

resultsdir=

echo "GHRSS processing pipeline"
hostname

cd $work_dir

file=$1

echo "Processing file $file"

file_dir=$(dirname $file)
# use string before _gsb as a folder name for the output
# this is ugly - get the directory and use text after directory, NOT 322/
# this changes - sometimes it is HR.322/, sometimes 322.HR/ - need to take this into account
source_name=$(echo $file | sed 's/.*322.HR\/\([a-zA-Z0-9_\-]*\)_gsb.*/\1/')

echo "Processing source $source_name"

mkdir $source_name

# I don't want to see File exists error whenever mkdir wants to do something
while ! mkdir lock_file_prep &> /dev/null
do
	sleep 2m
done

# rsync part
rsync -avP hydrus:${file} ${source_name}.gmrt_dat
rsync -av hydrus:${file}.gmrt_hdr ${source_name}.gmrt_hdr

# convert raw file to filterbank format
time filterbank ${source_name}.gmrt_dat > ${work_dir}/${source_name}/${source_name}.fil

# apply zerodm algorithm and remove the original non-zerodm filterbank file
time zerodm-gpu ${work_dir}/${source_name}/${source_name}.fil > ${work_dir}/${source_name}/zerodm${source_name}.fil
rm ${work_dir}/${source_name}/${source_name}.fil

# remove the temporary files
rm ${source_name}.gmrt_dat
rm ${source_name}.gmrt_hdr


# remove the file preparation lock
rmdir lock_file_prep

processed=0

while ! mkdir lock_gpu &> lock.log
do
	sleep 2m
done

echo "Starting GPU processing"

# -m is for the minimum SNR to be accepted as a candidate for pulsar search
# --npdmp is the maximum number of pulsar candidates to fold
################################################
# REMEMBER TO CHECK IF ACCELERATION SEARCH IS ON
################################################

mkdir pulsar_lock

Bifrost/bin/bifrost -f ${work_dir}/${source_name}/zerodm${source_name}.fil -t 4 --acc_start -250 --acc_end 250 --acc_tol 2.5 --dm_start 0 --dm_end 2000 --both --npdmp 200 -m 10 -o ${source_name} > ${source_name}/output.dat &

# Bifrost will remove this directory at the end of the pulsar processing
while [ -d pulsar_lock ]
do
	sleep 2m
done

# move statistic output files
mv means_values* ${source_name}

# start the post processing pipeline
post_processing_parallel_perf.sh ${source_name}

# single pulse seach should be long done by the time post-processing finishes
# cat all candidate files into one, move into correct folder and clean
cat ${source_name}/*.cand > ${source_name}/all_cands


rm ${work_dir}/${source_name}/zerodm${source_name}.fil

# copy results to results directory
# compute-0-67:/state/partition1/mmalenta/GMRT_RESULTS/
# consider copying to the external connected to vod
rsync -avP ./${source_name} $resultsdir

# add the file into the list of processed files
# not making any use of it at the moment
echo $source_name >> ${scriptdir}/processed.dat

rmdir lock_gpu

# not atomic - possible race conditions and horrible mistakes
while ! mkdir lock_job_save &>> lock.log
do
	sleep 1s
done

jobs=$(cat )
((jobs--))
echo $jobs >
rmdir lock_job_save

# move on
