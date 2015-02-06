#!/bin/bash

# Script to refine data with refined geometry parameters from integration and scaling

# Written by Donald Raymond [raymond [at] crystal.harvard.edu]
# last edited January 6rd 2015
#
##################################################################

#for debugging
#set -x

#Redirect STDOUT of the script output to a log file
exec >  >(tee  Reprocessing.log)
exec 2> >(tee  Reprocessing.log >&2)

#Declare functions

#Function to display introduction
function intro {
echo -e "\n*********************************************************\n
This is a bash script to reprocess data with XDS using the
correct spacegroup, refined geometry and fine-slicing of profiles
AND/OR with refined values for beam divergence and mosaicity
\n*********************************************************\n"
}


#Function to backup files
function backup {
if [ -e $1 ]; then
    cp $1 reprocess/"$1"_"$2"
else
    echo -e "\nCannot find $1\n"
    echo -e "Process data once before running this script\n"
    rm -rf log reprocess
    exit 1
fi
}

#Function to copy files
function copyFiles {
backup XPARM.XDS $1
backup INTEGRATE.LP $1
backup INTEGRATE.HKL $1
backup CORRECT.LP $1
backup XDS_ASCII.HKL $1
backup FRAME.cbf $1
backup XDS.INP $1
backup GXPARM.XDS $1
}

#Function to get number of cycles
function get_number {
check="fail"
while [[ "$check" = "fail" ]]; do
	echo -n "Number of cycles with $1: "
    read number

    if ! [ "$number" -eq "$number" ] 2> /dev/null || [ "$number" -lt "0" ] 2> /dev/null; then
        echo -e "\nInvalid input\n"
    else 
        echo -e "\nRunning $number cycles with $1"
        check="pass"
    fi  
done
echo
}

#function to create directories
function make_dir {
if [ ! -d $1 ]; then
    mkdir $1 
    echo -e "Created $1 directory\n"
else
    echo -e "$1 directory exists\n"
fi
}

#Function to loop refinement runs
function loop_refine {
for x in $(seq -f "%02g" 1 $1); do
    echo -e "Reprocessing with $2: Cycle $x of $(printf %02d $1)\n"
    repro $x
    stats "for cycle $x"
    copyFiles "$3"_$x
done
}

#Function to run XDS
function run_xds {
if [[ "$input_mode" = "s" ]] || [[ "$input_mode" = "S" ]]; then
	echo -e "Running XDS in silent mode\n"
	xds_par > log/Reprocess_noBEAM_$1.log
else
	echo -e "Running XDS in Verbose mode\n"
	xds_par |tee log/Reprocess_noBEAM_$1.log
fi
}

#Function to reprocess with correct spacegroup, refined geometry and fine-slicing of profiles
function repro {
echo -e "Creating a new XDS.INP with the correct spacegroup, refined geometry and fine-slicing of profiles\n"
egrep -v 'JOB|REIDX' XDS.INP | egrep -v "NUMBER_OF_PROFILE_GRID_POINTS_ALONG_" > XDS.INP_new
echo "! JOB=XYCORR INIT COLSPOT IDXREF DEFPIX INTEGRATE CORRECT" > XDS.INP
echo "JOB=INTEGRATE CORRECT" >> XDS.INP
echo NUMBER_OF_PROFILE_GRID_POINTS_ALONG_ALPHA/BETA=13 >> XDS.INP ! default is 9
echo NUMBER_OF_PROFILE_GRID_POINTS_ALONG_GAMMA=13      >> XDS.INP ! default is 9
cat XDS.INP_new >> XDS.INP
echo -e "Reprocessing with the correct spacegroup, refined geometry and fine-slicing of profiles\n"
run_xds $1
}

#function to reprocess with refined values for beam divergence and mosaicity
function repro_BEAM {
echo -e "Creating a new XDS.INP with refined values for beam divergence and mosaicity\n"
grep _E INTEGRATE.LP | tail -2 > x
grep -v _E.S.D XDS.INP >> x
cp x XDS.INP
cp XDS.INP XDS.INP_BEAM
echo -e "Reprocessing XDS with refined values for beam divergence and mosaicity\n"
run_xds $1
}

#function to get scaling statisticss table
function stats {
echo -e "Scaling statistics $1\n"
egrep -B 25 "WILSON STATISTICS OF DATA SET" "$2"CORRECT.LP"$3" | egrep -A 20  "SUBSET OF INTENSITY DATA WITH SIGNAL/NOISE"
echo -e "\n####################################################\n\n"
}
###########################################################
### RUNNING SCRIPT
#######################################

#clear terminal screen
clear

#Show script intro
intro

# Get running mode
echo -n "Run XDS in Silent (S) or Verbose (V) mode? "
while read -r -n 1 -s input_mode; do
	if [[ $input_mode = [SsVv] ]]; then
		[[ $input_mode = [Ss] ]] && echo -e "\n\nRunning XDS in silent mode\n"
		[[ $input_mode = [Vv] ]] && echo -e "\n\nRunning XDS in verbose mode\n"
		break
	fi
done

#get number of cycles

# REFINED GEOMETRY AND FINE-SLICING OF PROFILES cycles
get_number "REFINED GEOMETRY AND FINE-SLICING OF PROFILES" && reproc=$number

# REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY cycles
get_number "REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY" && beam_reproc=$number

#make log directory
make_dir "log"

#make reprocess directory
make_dir "reprocess"

#########################################################

#Save initial files
echo "Saving initial files"
copyFiles ini

#get stats table before reprocessing
echo;stats "before refinement"

#Loop for reprocessing without BEAM optimzation
loop_refine "$reproc" "REFINED GEOMETRY AND FINE-SLICING OF PROFILES" "repro" && i=$x

#loop for reprocessing with BEAM optimization
loop_refine "$beam_reproc" "REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY" "BEAM"  && j=$x

#Move log file to reprocess folder
mv Reprocessing.log reprocess/ 
echo -e "Reprocessing finished\n"

#compare stats from different runs
echo -e "\n**************************************************************
**************************************************************
\t\tREFINEMENT SUMMARY
**************************************************************
**************************************************************\n"
#stats from CORRECT LP before refinement
stats "before refinement" "reprocess/" "_ini"

#stats from CORRECt LP after Reprocessing with REFINED GEOMETRY AND FINE-SLICING OF PROFILES
stats "after Reprocessing with REFINED GEOMETRY AND FINE-SLICING OF PROFILES" "reprocess/" "_repro_$i"

#stats from CORRECT LP after Reprocessing with REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY
stats "after Reprocessing with REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY" "reprocess/" "_BEAM_$j"

#end script
echo -e "\nScript finished\n"
