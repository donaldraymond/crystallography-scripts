#!/bin/bash

# Script to refine data with refined geometry parameters from integration and scaling

# Written by Donald Raymond [raymond@crystal.harvard.edu]
# last edited January 2nd 2015
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

#Function to backup existing files
function copyFiles {
	if [ -e XPARM.XDS ]; then
		cp XPARM.XDS reprocess/XPARM.XDS_$1
	else
		echo -e "\nCannot find XPARMS.XDS\n"
		echo -e "Process data once before running this script\n"
		rm -rf log reprocess
		exit 1
	fi

	if [ -e INTEGRATE.LP ]; then
		cp INTEGRATE.LP reprocess/INTEGRATE.LP_$1
	else
		echo -e "\nCannot find INTEGRATE.LP\n"
		echo -e "Process data once before running this script\n"
		rm -rf log reprocess
		exit 1
	fi

	if [ -e INTEGRATE.HKL ]; then
		cp INTEGRATE.HKL reprocess/INTEGRATE.HKL_$1
	else
		echo -e "\nCannot find INTEGRATE.HKL\n"
		echo -e "Process data once before running this script\n"
		rm -rf log reprocess
		exit 1
	fi

	if [ -e CORRECT.LP ]; then
		cp CORRECT.LP reprocess/CORRECT.LP_$1
	else
		echo -e "\nCannot find CORRECT.LP\n"
		echo -e "Process data once before running this script\n"
		rm -rf log reprocess
		exit 1
	fi

	if [ -e XDS_ASCII.HKL ]; then
		cp XDS_ASCII.HKL reprocess/XDS_ASCII.HKL_$1
	else
		echo -e "\nCannot find XDS_ASCII.HKL\n"
		echo -e "Process data once before running this script\n"
		rm -rf log reprocess
		exit 1
	fi
	
	if [ -e FRAME.cbf ]; then
		cp FRAME.cbf reprocess/FRAME_$1.cbf
	else
		echo -e "\nFRAME.cbf\n"
		echo -e "Process data once before running this script\n"
		rm -rf log reprocess
		exit 1
	fi

	if [ -e XDS.INP ]; then
		cp XDS.INP reprocess/XDS.INP_$1
	else
		echo -e "\nCannot find XDS.INP\n"
		exit 1
	fi

	if [ -e GXPARM.XDS ]; then
		cp GXPARM.XDS reprocess/GXPARM.XDS_$1
	else
		echo -e "\nCannot find GXPARM.XDS\n"
		exit 1
	fi

	if [ -e GXPARM.XDS ]; then
		cp GXPARM.XDS reprocess/XPARM.XDS
	else
		echo -e "\nCannot find GXPARM.XDS\n"
		exit 1
	fi
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


#create log dir
if [ ! -d log ]; then
    mkdir log
	echo -e "Created log directory\n"
else
	echo -e "Log directory exists\n"
fi

#create reprocess dir
if [ ! -d reprocess ]; then
    mkdir reprocess
	echo -e "Created reprocess directory\n"
else
	echo -e "Reprocess directory exists\n"
fi

#########################################################

#Save initial files
echo "Saving initial files"
copyFiles ini

#get stats table before reprocessing
echo;stats "before refinement"

#Loop for reprocessing without BEAM optimzation
for i in $(seq -f "%02g" 1 $reproc); do
	echo -e "Reprocessing with REFINED GEOMETRY AND FINE-SLICING OF PROFILES: Cycle $i of $(printf %02d $reproc)\n"
	repro $i
	stats "for cycle $i"
	copyFiles repro_$i
done

#loop for reprocessing with BEAM optimization
for j in $(seq -f "%02g" 1 $beam_reproc); do
	echo -e "Reprocessing with REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY: Cycle $j of $(printf %02d $beam_reproc)\n"
	repro_BEAM $j
	stats "for cycle $j"
	copyFiles BEAM_$j
done

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
