#!/bin/sh
set -euo pipefail

# Description: shell script to launch bioinformatics analysis pipelines.
# This script should be executed as sbsuser 
# Date: 18/08/20
version="1.2.0"

# use to read raw data
bcl_raw_read="/data/raw"

# use to write to archive 
bcl_arc_write="/data_heath/archive"

# use to read from archive
bcl_arc_read="/data/archive"

# user to write from childnodes
fastq_write="/Output/fastq"

function processJobs {
    echo "checking for jobs in $1 ..."

    for path in $(find "$1" -maxdepth 2 -mindepth 2 -type f -name "RTAComplete.txt" -exec dirname '{}' \;); do

        # extract run info from path
        instrumentType=$(basename $(dirname "$path"))
        run=$(basename "$path")

        # log
	echo "path: $path"
        echo "run: $run"
        echo "instrumentType: $instrumentType"

        # move run to archive
        mv "$path" "$bcl_arc_write/$instrumentType/$run"

        # change access permissions
        chmod -R 755 "$bcl_arc_write"/"$instrumentType"/"$run"
        chmod 777 "$bcl_arc_write"/"$instrumentType"/"$run"/SampleSheet.csv

        # launch IlluminaQC for demultiplexing and QC
        # currently, data is read from the Heath Isilon. Whilst not ideal, it may be preferable to a sleep while nodes sync 
        ssh transfer@172.25.0.1 "mkdir $fastq_write/$run && cd $fastq_write/$run && sbatch -J IlluminaQC-"$run" --export=sourceDir=$bcl_arc_write/$instrumentType/$run /data/diagnostics/pipelines/IlluminaQC/IlluminaQC-$version/1_IlluminaQC.sh"

    done

}

#processJobs "$bcl_raw_dir/hiseq"
processJobs "$bcl_raw_dir/nextseq"
#processJobs "$bcl_raw_dir/novaseq"
#processJobs "$bcl_raw_dir/miseq"
