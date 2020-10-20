#!/bin/sh
set -euo pipefail

# Description: shell script to launch bioinformatics analysis pipelines.
# This script should be executed as sbsuser 
# Date: 18/08/20
version="1.2.0"

# use to write raw data
raw_write="/data_heath/raw"

# where IlluminaQC reads data from
raw_read="/data/raw"

# use to write to archive 
arc_write="/data_heath/archive"

# use to read from archive
arc_read="/data/archive"

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
        cp -r "$raw_write/$instrumentType/$run" "$arc_write/$instrumentType/$run"

        # change access permissions
        chmod -R 755 "$arc_write"/"$instrumentType"/"$run"
        chmod 777 "$arc_write"/"$instrumentType"/"$run"/SampleSheet.csv

        # modify RTAComplete to prevent cron re-triggering
        mv $raw_write/$instrumentType/$run/RTAComplete.txt $raw_write/$instrumentType/$run/_RTAComplete.txt

        sleep 5m

        # launch IlluminaQC for demultiplexing and QC 
        ssh transfer "mkdir $fastq_write/$run && cd $fastq_write/$run && sbatch -J IlluminaQC-"$run" --export=sourceDir=$path /data/diagnostics/pipelines/IlluminaQC/IlluminaQC-$version/1_IlluminaQC.sh"

    done

}

#processJobs "$raw_read/hiseq"
processJobs "$raw_read/nextseq"
#processJobs "$raw_read/novaseq"
#processJobs "$raw_read/miseq"
