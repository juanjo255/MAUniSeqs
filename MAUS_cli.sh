## options

wd="./MAUS_result/"
prefix1=""
prefix2=""
threads=4
fastp_options=""
read_len=100
classification_level="F"
threshold_abundance=0
kmer_len=35
build_db=0
libraries="bacteria,archaea,viral,human,UniVec_Core"

MAUS_help() {
    echo "
    MAUS - Metagenome Analyse pipeline UniSeqs

    Author:
    Juan Picon Cossio

    Version: 0.1

    Usage: MAUS_cli.sh [options] -1 reads_R1.fastq -2 reads_R2.fastq
--thread
    Options:
        -1        Input R1 paired end file. [required].
        -2        Input R2 paired end file. [required].
        -d        Database for kraken. if you do not have one, create one before using this pipeline. [required].
        -n        Build kraken2 and Bracken database (Use with -g for library download). [False].
        -g        Libraries. It can accept a comma-delimited list with: archaea, bacteria, plasmid, viral, human, fungi, plant, protozoa, nr, nt, UniVec, UniVec_Core. [kraken2 standard].
        -t        Threads. [4].
        -w        Working directory. Path to create the folder which will contain all MAUS information. [./MAUS_result].
        -z        Different output directory. Create a different output directory every run (it uses the date and time). [False].
        -f        FastP options. [\" \"].
        -l        Read length (Bracken). [100].
        -c        Classification level (Bracken) [options: D,P,C,O,F,G,S,S1,etc]. [F]
        -s        Threshold before abundance estimation (Bracken). [0].
        -k        kmer length. (Kraken2,Bracken).[35]

        *         Help.
    "
    exit 1
}
while getopts '1:2:d:ng:t:w:z:f:l:c:s:k:' opt; do
    case $opt in
        1)
        input_R1_file=$OPTARG
        ;;
        2)
        input_R2_file=$OPTARG
        ;;
        d)
        kraken2_db=$OPTARG
        ;;
        n)
        build_db=1
        ;;
        g)
        libraries=$OPTARG
        ;;
        t)
        threads=$OPTARG
        ;;
        w)
        wd=$OPTARG
        ;;
        z)
        output_dir="MAUS_result_$(date  "+%Y-%m-%d_%H-%M-%S")/"
        ;;
        f)
        fastp_options=$OPTARG
        ;;
        l)
        read_len=$OPTARG
        ;;
        c)
        classification_level=$OPTARG
        ;;
        s)
        threshold_abundance=$OPTARG
        ;;
        k)
        kmer_len=$OPTARG
        ;;
        *)
        MAUS_help
        ;;
    esac
done

#### OPTIONS CHECKING #####
## If no option given, print help
if [ $OPTIND -eq 1 ]; then MAUS_help; fi

## Check required files are available
if [ -z $input_R1_file ]; then echo "ERROR => File 1 is missing"; MAUS_help; fi
if [ -z $input_R2_file ]; then echo "ERROR => File 2 is missing"; MAUS_help; fi
if [ -z $kraken2_db ]; then echo "ERROR => Kraken2 database is missing"; MAUS_help; fi

## Check if working directory has the last slash
if [ ${wd: -1} = / ];
then 
    wd=$wd$output_dir
else
    wd=$wd"/"$output_dir
fi

## PREFIX name to use for the resulting files
if [ -z $prefix1 ];
then 
    prefix1=$(basename $input_R1_file)
    prefix1=${prefix1%%.*}
fi

## PREFIX name to use for the resulting files
if [ -z $prefix2 ];
then 
    prefix2=$(basename $input_R2_file)
    prefix2=${prefix2%%.*}
fi


#### FUNCTIONS FOR PIPELINE ####

create_wd (){
    mkdir $wd
    echo "Output directory created" 
}

## FastP preprocessing
fastp_preprocess (){
    echo "**** Quality filter with fastp *****"
    echo " "
    echo "FastP options: $fastp_options"
    fastp --thread $threads -i $input_R1_file -I $input_R2_file $fastp_options -o $wd$prefix1".filt.fastq" -O $wd$prefix2".filt.fastq" -j $wd$prefix2".html" -h $wd$prefix2".json"
}

kraken2_build_db (){
    echo "**** Downloading required files for kraken2 database *****"
    echo " "

    ## Download taxonomy
    if [ -f $kraken2_db"/taxonomy/nucl_gb.accession2taxid" ] || [ -f $kraken2_db"/taxonomy/nucl_wgs.accession2taxid" ]; then
        echo "Taxonomy files exist"
    else
        k2 download-taxonomy --db $kraken2_db
    fi

    ## Download libraries
    k2 download-library --db $kraken2_db --library $libraries && kraken2-build --build --db $kraken2_db --threads $threads
    
}
## bracken build database
bracken_build_db (){
    echo "**** Building Bracken database *****"
    echo " "
    bracken-build -d $kraken2_db -t $threads -k $kmer_len -l $read_len && kraken2-build --clean
    echo " "
    echo "**** Unneeded files were removed *****"
    echo " "
}

## Kraken2 classification
Kraken2_classification (){
    echo "**** Read classification with Kraken2 *****"
    echo " "
    kraken2 --threads $threads --db $kraken2_db --report $wd$prefix1$prefix2".kraken2_report" --report-minimizer-data --use-mpa-style \
        --output $wd$prefix1$prefix2".kraken2_output" $input_R1_file $input_R2_file 
}

## Bracken abundance estimation
bracken_estimation (){
    echo "**** Abundance estimation with Bracken *****"
    echo " "
    bracken -d $kraken2_db -i $wd$prefix1$prefix2".kraken2_report" -r $read_len -l $classification_level -t $threshold_abundance \ 
        -o $wd$prefix1$prefix2".bracken_output"
}

## Krona visualization of Bracken results
krona_plot (){
    echo "**** Plotting Bracken results with Krona *****"
    echo " "
    ln -s /path/on/big/disk/taxonomy /home/genmol1/miniforge3/envs/MAUS/opt/krona/taxonomy
    ##ktImportTaxonomy -t 5 -m 3 -o $wd$prefix1$prefix2".krona.html" $wd$prefix1$prefix2".kraken2_report"  
}


## PIPELINE

## Check if output directory exists
if [ -d $wd ];
then
    echo "Directory exists."
else 
    create_wd
fi

if [ $build_db -eq 1 ];
then
    echo "**** Building databases for kraken2 and Bracken *****"
    echo " " 
    kraken2_build_db && bracken_build_db
fi

#fastp_preprocess && Kraken2_classification && bracken_estimation