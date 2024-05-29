## options

fastp_options=" "
wd="./MAUS_result/"
prefix1=""
prefix2=""

MAUS_help() {
    echo "
    MAUS - Metagenome Analyse pipeline UniSeqs

    Author:
    Juan Picon Cossio

    Version: 0.1

    Usage: MAUS_cli.sh [options] -1 reads_R1.fastq -2 reads_R2.fastq

    Options:
        -1        Input R1 paired end file. [required].
        -2        Input R2 paired end file. [required].
        -t        Threads. [4].
        -w        Working directory. Path to create the folder which will contain all MAUS information. [./MAUS_result].
        -d        Different output directory. Create a different output directory every run (it uses the date and time). [False].
        -f        FastP options. [\" \"].
        *         Help.
    "
    exit 1
}
while getopts '1:2:t:w:d:f:' opt; do
    case $opt in
        1)
        input_R1_file=$OPTARG
        ;;
        2)
        input_R2_file=$OPTARG
        ;;
        t)
        threads=$OPTARG
        ;;
        w)
        wd=$OPTARG
        ;;
        d)
        output_dir="MAUS_result_$(date  "+%Y-%m-%d_%H-%M-%S")/"
        ;;
        f)
        fastp_options=$OPTARG
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
    fastp -i $input_R1_file -I $input_R2_file $fastp_options -o $wd$prefix1".filt.fastq" -O $wd$prefix2".filt.fastq" -j $wd$prefix2".html" -h $wd$prefix2".json"
}


## PIPELINE

## Check if output directory exists
if [ -d $wd ];
then
  echo "Directory exists."
else 
    create_wd
fi

fastp_preprocess