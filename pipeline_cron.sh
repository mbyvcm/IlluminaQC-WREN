#!/bin/sh
#set -euo pipefail

#Description: shell script to launch bioinformatics analysis pipelines. Run as root cron job without .sh extension
#Author:Matt Lyon
#Date: 17/09/19
version="1.1.0"

function processJobs {
    echo "checking for jobs in $1 ..."

    for path in $(find "$1" -maxdepth 2 -mindepth 2 -type f -name "RTAComplete.txt" -exec dirname '{}' \;); do
        

        #extract run info from path
        instrumentType=$(basename $(dirname "$path"))
        run=$(basename "$path")
        
        #if the sample sheet exists
	if [ -f "/data/raw/$instrumentType/$run/SampleSheet.csv" ]; then
        
        #check whether it has Dragen in it
        set +u
	dragen="$(grep Dragen /data/raw/"$instrumentType"/"$run"/SampleSheet.csv | wc -l)"
        echo $dragen
        set -u
        else

        echo could not find sample sheet

        dragen=0

        fi

	if [ $dragen -gt 0 ]
	  then

	  echo "processing on Dragen"
          #move to novaseq dir
	  mv "$path" /data/raw/novaseq/ 
          #fix permissions          
          chown -R sbsuser /data/raw/novaseq/"$run"
          chgrp -R bi /data/raw/novaseq/"$run"
          chmod -R 755 /data/raw/novaseq/"$run"
          

        else


          #log
	  echo "path: $path"
          echo "run: $run"
          echo "instrumentType: $instrumentType"

          #move run to archive
          mv "$path" /data/archive/"$instrumentType"
          
          touch /data/archive/"$instrumentType"/"$run"/run_copy_complete.txt

          #change access permissions
          chown -R transfer /data/archive/"$instrumentType"/"$run"
          chgrp -R transfer /data/archive/"$instrumentType"/"$run"
          chmod -R 755 /data/archive/"$instrumentType"/"$run"

          #launch IlluminaQC for demultiplexing and QC
          ssh transfer@10.59.210.245 "mkdir /data/archive/fastq/$run && cd /data/archive/fastq/$run && qsub -v sourceDir=/data/archive/$instrumentType/$run /data/diagnostics/pipelines/IlluminaQC/IlluminaQC-$version/1_IlluminaQC.sh"

       fi

    done


}

processJobs "/data/raw/miseq"
processJobs "/data/raw/hiseq"
processJobs "/data/raw/nextseq"
