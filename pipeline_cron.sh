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
        
        if [ -f "$path"/do_not_process ]; then

            echo "Not processing run $run"
        else

            # only run if novaseq and CopyComplete.txt is here - if other sequencer then do not care
            
            if [[ -f $raw_write/$instrumentType/$run/CopyComplete.txt && "$instrumentType" = "novaseq" ]] || [[ "$instrumentType" != "novaseq"  ]] ;
            then

                if [ -f $raw_write/$instrumentType/$run/SampleSheet.csv ]; then

                    # remove spaces from sample sheet
                    sed -i 's/ //g' $raw_write/$instrumentType/$run/SampleSheet.csv
                
                    # modify RTAComplete to prevent cron re-triggering
                    mv $raw_write/$instrumentType/$run/RTAComplete.txt $raw_write/$instrumentType/$run/_RTAComplete.txt

                    #allow time for changes to copy from data_heath to data
                    sleep 5m

                    # counting instances of Dragen in SampleSheet
                    set +e
                    is_dragen=$(cat "$path"/SampleSheet.csv | grep "Dragen" | wc -l)
                    is_tso500=$(cat "$path"/SampleSheet.csv | grep "TSO500" | wc -l)
                    set -e

                    if [ $is_dragen -gt 0 ]; then

                         echo "Keyword Dragen found in SampleSheet so executing DragenQC"
                         ssh ch1 "mkdir $fastq_write/$run && cd $fastq_write/$run && sbatch --export=sourceDir=$path /data/diagnostics/pipelines/DragenQC/DragenQC-master/DragenQC.sh"

                     elif [ $is_tso500 -gt 0 ]; then

                         echo "Keyword TSO500 found in SampleSheet so executing TSO500 pipeline"
                         ssh ch1 "mkdir /Output/results/$run && cd /Output/results/$run && cp /data/diagnostics/pipelines/TSO500/TSO500_post_processing-master/*_TSO500.sh . && sbatch --export=raw_data=$path 1_TSO500.sh"

                     else
                         # launch IlluminaQC for demultiplexing and QC
                         ssh ch1 "mkdir $fastq_write/$run && cd $fastq_write/$run && sbatch -J IlluminaQC-"$run" --export=sourceDir=$path /data/diagnostics/pipelines/IlluminaQC/IlluminaQC-$version/1_IlluminaQC.sh"

                     fi

                     # check we havent already copied the directory
                     if [ -d "$arc_write/$instrumentType/$run" ]; then

                         echo "$arc_write/$instrumentType/$run already exists"
                     else

                         # move run to archive
                         cp -r "$raw_write/$instrumentType/$run" "$arc_write/$instrumentType/$run"

                         touch "$arc_write/$instrumentType/$run"/run_copy_complete.txt

                         # change access permissions
                         chmod -R 755 "$arc_write"/"$instrumentType"/"$run"
                         chmod 777 "$arc_write"/"$instrumentType"/"$run"/SampleSheet.csv
            
                     fi

                 else

                     echo "Not running as no sample sheet"

                 fi

          else

              echo "Not running Novaseq unless CopyComplete.txt is there"
    
          fi
        fi

	

    done
}

#processJobs "$raw_read/hiseq"
processJobs "$raw_read/nextseq"
processJobs "$raw_read/novaseq"
processJobs "$raw_read/miseq"
