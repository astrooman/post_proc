#!/bin/sh
# node kickstarting with locks implemented
# need to check if there there are no locks on file preparation and at least one GPU
# use semaphore for sending new jobs

# lock_job_query

MAX_JOBS=3

work_dir=

# don't want two or more jobs accessing and changing the log file at the same time
while ! mkdir lock_job_query
do
	sleep 10s
done

jobs=$(cat )

while [ $jobs == $MAX_JOBS ]
do
	sleep 2m
	jobs=$(cat )
done

((jobs++))
echo $jobs >

rmdir lock_job_query

/bin/bash node_processing_parallel $file 2>&1 | tee /tmp/GMRT_${jobs}.log

# keep it for testing purposes
