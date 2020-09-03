#!/bin/sh
set -euo pipefail

# Description: shell script to launch bioinformatics analysis pipelines. Run as root cron job without .sh extension
# Date: 18/08/20
version="1.2.0"

bcl_raw_dir="/home/transfer/data/raw"
bcl_arc_dir="/home/transfer/data/archive"
fastq_dir="/home/transfer/data/archive/fastq"


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

        # move run to archive - CHANGE FROM CP
        #cp -r "$path" "$bcl_arc_dir/$instrumentType/$run"

        # change access permissions
        #chown -R transfer "$bcl_arc_dir"/"$instrumentType"/"$run"
        #chgrp -R transfer "$bcl_arc_dir"/"$instrumentType"/"$run"
        #chmod -R 755 "$bcl_arc_dir"/"$instrumentType"/"$run"

        # launch IlluminaQC for demultiplexing and QC
        mkdir $fastq_dir/$run && cd $fastq_dir/$run
        sbatch -J IlluminaQC-"$run" --export=sourceDir=$bcl_arc_dir/$instrumentType/$run /data/diagnostics/pipelines/IlluminaQC/IlluminaQC-$version/1_IlluminaQC.sh

    done

}

processJobs "$bcl_raw_dir/hiseq"
processJobs "$bcl_raw_dir/nextseq"
processJobs "$bcl_raw_dir/novaseq"
processJobs "$bcl_raw_dir/miseq"
