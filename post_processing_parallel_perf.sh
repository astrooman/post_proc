#!/bin/bash

# the most coputationally-intensive part of the
# post-processing pipeline: dspsr and pdmp
# to run this script, zerodm filterbank file
# has to be presend in the source directory
# as the file preparation stage has been removed

export OMP_NUM_THREADS=8

# for our GHRSS parameters
CONST=0.036422

# work in the same directory as the detection pipeline
work_dir=

source=$1

cd $work_dir

# all the work will be done in the observation directory
cd ./${source}

# remove spaces at the start of every line
sed -e 's/^[ \t]*//' pulsar_search_overview.xml > no_space_pulsar_search_overview.xml

	sed -n -e "/<candidate id='\([0-9]*\)'>/{
                N
                N
                N
                N
                N
                N
                N
                        s/<candidate id='\([0-9]*\)'>\n<period>\([.0-9]*\)<\/period>\n<opt_period>\([.0-9]*\)<\/opt_period>\n<dm>\([.0-9]*\)<\/dm>\n<acc>\([.0-9\-]*\)<\/acc>\n<nh>\([.0-9]*\)<\/nh>\n<snr>\([.0-9]*\)<\/snr>\n<folded_snr>\([.0-9\-]*\)<\/folded_snr>/\1 \2 \3 \4 \5 \7 \8/p }" no_space_pulsar_search_overview.xml > short_candidates.dat

# create candidate files for dspsr
mkdir cand_files

cands_no=$( wc -l < short_candidates.dat )

echo $cands_no

FILE_PER_GROUP=10

cand_num=0
good_cand_num=0
while read line
do

        arr=( $line )

        id=${arr[0]}
	period=${arr[1]}
	dm=${arr[3]}
	acc=${arr[4]}
	snr=${arr[5]}

	dm_arr[cand_num]=$dm
	period_arr[cand_num]=$period

	if (( $( echo "${dm} != 0" | bc ) ))
	then

		good_cand_id[good_cand_num]=$id
		good_cand_num=$((good_cand_num+1))

	fi

        touch ./cand_files/cand_${id}.dat

        echo SOURCE: cand_${id} >> ./cand_files/cand_${id}.dat
        echo PERIOD: $period >> ./cand_files/cand_${id}.dat
        echo DM: $dm >> ./cand_files/cand_${id}.dat
        echo ACC: $acc >> ./cand_files/cand_${id}.dat

	cand_num=$((cand_num+1))

done < short_candidates.dat

echo $good_cand_num

# interested in processing good candidates only
no_groups=$((good_cand_num / FILE_PER_GROUP))
rem_cands=$((good_cand_num % FILE_PER_GROUP))

echo $no_groups
echo $rem_cands

# make sure we dont process files that have dm equal to 0
# process groups
for (( group=0; group<$no_groups; group++ ))
do

	echo "Processing group $group"

	FILES="" # need to clean the files string for every group

        for (( file=0; file<$FILE_PER_GROUP; file++ ))
        do

		good_id=$((group * FILE_PER_GROUP + file))
		cand_id=${good_cand_id[$good_id]}

		FILES="$FILES -P ./cand_files/cand_${cand_id}.dat"
	done

	echo $FILES

	# not using -L option as it seems to bring the dspsr execution
	# to a halt when more than one or two threads are used
	time dspsr $FILES ./zerodm${source}.fil -t 8

done

# process files the remaining files that did not fill the whole group
echo "Processing group $no_groups"

FILES=""

good_cands=0

for (( file=0; file<$rem_cands; file++ ))
do

	good_id=$((group * FILE_PER_GROUP + file))
	cand_id=${good_cand_id[$good_id]}

	FILES="$FILES -P ./cand_files/cand_${cand_id}.dat"

done

time dspsr $FILES ./zerodm${source}.fil -t 8

if (( $rem_cands == 1 ))
then
	ID=$( echo $FILES | sed 's/.*cand_\([0-9]*\).dat/\1/' )
        mkdir cand_${ID}
        mv *.ar ./cand_${ID}
fi

# remove any possible locks on GPUs
# as pdmpd will no make use of them

for (( file=0; file<$good_cands_num; file++ ))
do

	cand_id=${good_cand_id[$file]}

        cd ./cand_${cand_id}

        mv *.ar ./candidate_${cand_id}.ar
        pam --setnchn 16 -e f16 candidate_${cand_id}.ar

        # period has to be in milliseconds (originally in seconds)
        dmr=$( echo "${CONST} * ${period_arr[${cand_id}]} * 1000" | bc )
        dms=$( echo "scale=10; ${dmr} / 20.0" | bc )
	# -dr - DM half-range, -ds - DM step size
        pdmp -g candidate_${cand_id}.ps/PS -dr $dmr -ds $dms -o$
        cd ../

done

# file removing will be dealt with in the main script
