#!/bin/bash

# Script to refine data with refined geometry parameters from integration and scaling

# Written by Donald Raymond [raymond@crystal.harvard.edu]
# last edited Decemember 8th 2014
#
##################################################################

#Redirect STDOUT of the script output to a log file
exec >  >(tee  Reprocessing.log)
exec 2> >(tee  Reprocessing.log >&2)

#Declare functions

#Function to display introduction
function intro {
	echo
	echo "*********************************************************"
	echo
	echo "This is a bash script to reprocess data with XDS using the"
	echo "correct spacegroup, refined geometry and fine-slicing of profiles"
	echo "AND/OR with refined values for beam divergence and mosaicity"
	echo 
	echo "*********************************************************"
	echo
}

#Function to backup existing files
function copyFiles {
	if [ -e XPARM.XDS ]; then
		cp XPARM.XDS reprocess/XPARM.XDS_$1
	else
		echo;echo "Cannot find XPARMS.XDS";echo
		echo "Process data once before running this script";echo
		rm -rf log reprocess
		exit 1
	fi

	if [ -e INTEGRATE.LP ]; then
		cp INTEGRATE.LP reprocess/INTEGRATE.LP_$1
	else
		echo;echo "Cannot find INTEGRATE.LP";echo
		echo "Process data once before running this script";echo
		rm -rf log reprocess
		exit 1
	fi

	if [ -e INTEGRATE.HKL ]; then
		cp INTEGRATE.HKL reprocess/INTEGRATE.HKL_$1
	else
		echo;echo "Cannot find INTEGRATE.HKL";echo
		echo "Process data once before running this script";echo
		rm -rf log reprocess
		exit 1
	fi

	if [ -e CORRECT.LP ]; then
		cp CORRECT.LP reprocess/CORRECT.LP_$1
	else
		echo;echo "Cannot find CORRECT.LP";echo
		echo "Process data once before running this script";echo
		rm -rf log reprocess
		exit 1
	fi

	if [ -e XDS_ASCII.HKL ]; then
		cp XDS_ASCII.HKL reprocess/XDS_ASCII.HKL_$1
	else
		echo;echo "Cannot find XDS_ASCII.HKL";echo
		echo "Process data once before running this script";echo
		rm -rf log reprocess
		exit 1
	fi
	
	if [ -e FRAME.cbf ]; then
		cp FRAME.cbf reprocess/FRAME_$1.cbf
	else
		echo;echo "FRAME.cbf";echo
		echo "Process data once before running this script";echo
		rm -rf log reprocess
		exit 1
	fi

	if [ -e XDS.INP ]; then
		cp XDS.INP reprocess/XDS.INP_$1
	else
		echo "Cannot find XDS.INP";echo
		exit 1
	fi

	if [ -e GXPARM.XDS ]; then
		cp GXPARM.XDS reprocess/GXPARM.XDS_$1
	else
		echo "Cannot find GXPARM.XDS";echo
		exit 1
	fi

	if [ -e GXPARM.XDS ]; then
		cp GXPARM.XDS reprocess/XPARM.XDS
	else
		echo "Cannot find GXPARM.XDS";echo
		exit 1
	fi
}

#Function to run XDS
function run_xds {
if [[ "$input_mode" = "s" ]] || [[ "$input_mode" = "S" ]]; then
	echo "Running XDS in silent mode";echo
	xds_par > log/Reprocess_noBEAM_$1.log
else
	echo "Running XDS in Verbose mode";echo
	xds_par |tee log/Reprocess_noBEAM_$1.log
fi
}

#Function to reprocess with correct spacegroup, refined geometry and fine-slicing of profiles
function repro {
	echo "Creating a new XDS.INP with the correct spacegroup, refined geometry and fine-slicing of profiles";echo
	egrep -v 'JOB|REIDX' XDS.INP | egrep -v "NUMBER_OF_PROFILE_GRID_POINTS_ALONG_" > XDS.INP_new
	echo "! JOB=XYCORR INIT COLSPOT IDXREF DEFPIX INTEGRATE CORRECT" > XDS.INP
	echo "JOB=INTEGRATE CORRECT" >> XDS.INP
	echo NUMBER_OF_PROFILE_GRID_POINTS_ALONG_ALPHA/BETA=13 >> XDS.INP ! default is 9
	echo NUMBER_OF_PROFILE_GRID_POINTS_ALONG_GAMMA=13      >> XDS.INP ! default is 9
	cat XDS.INP_new >> XDS.INP
	echo "Reprocessing with the correct spacegroup, refined geometry and fine-slicing of profiles";echo
	run_xds $1
	}


#function to reprocess with refined values for beam divergence and mosaicity
function repro_BEAM {
	echo "Creating a new XDS.INP with refined values for beam divergence and mosaicity";echo
	grep _E INTEGRATE.LP | tail -2 > x
	grep -v _E.S.D XDS.INP >> x
	cp x XDS.INP
	cp XDS.INP XDS.INP_BEAM
	echo "Reprocessing XDS with refined values for beam divergence and mosaicity";echo
	run_xds $1
}

#function to get scaling statisticss table
function stats {
	echo "Scaling statistics for cycle: $1";echo
	egrep -B 25 "WILSON STATISTICS OF DATA SET" CORRECT.LP | egrep -A 21  "SUBSET OF INTENSITY DATA WITH SIGNAL/NOISE"
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
		[[ $input_mode = [Ss] ]] && echo && echo && echo "Running XDS in silent mode" && echo
		[[ $input_mode = [Vv] ]] && echo && echo && echo "Running XDS in verbose mode" && echo
		break
	fi
done

#get number of cycles

number_1="fail"
while [[ "$number_1" = "fail" ]]; do
	echo -n "Number of cycles with REFINED GEOMETRY AND FINE-SLICING OF PROFILES: "
	read reproc

	if ! [ "$reproc" -eq "$reproc" ] 2> /dev/null; then
		echo;echo "Invalid input";echo
	else 
		echo;echo "Running $reproc cycles with REFINED GEOMETRY AND FINE-SLICING OF PROFILES";echo
		number_1="pass"
	fi
done


number_2="fail"
while [[ "$number_2" = "fail" ]]; do
	echo -n "Number of cycles with REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY: "
	read beam_reproc

	if ! [ "$beam_reproc" -eq "$beam_reproc" ] 2> /dev/null; then
		echo;echo "Invalid input";echo
	else 
		echo;echo "Running $beam_reproc cycles with REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY";echo
		number_2="pass"
	fi
done


#create log dir
if [ ! -d log ]; then
    mkdir log
	echo "Created log directory";echo
else
	echo "Log directory exists";echo
fi

#create reprocess dir
if [ ! -d reprocess ]; then
    mkdir reprocess
	echo "Created reprocess directory";echo
else
	echo "Reprocess directory exists";echo
fi

#########################################################

#Save initial files
echo "Saving initial files"
copyFiles ini

#get stats table before reprocessing
echo;stats 00

#Loop for reprocessing without BEAM optimzation
for i in $(seq -f "%02g" 1 $reproc); do
	echo; echo "####################################################";echo
	echo "Reprocessing with REFINED GEOMETRY AND FINE-SLICING OF PROFILES: Cycle $i of $(printf %02d $reproc)";echo
	repro $i
	stats $i
	copyFiles repro_$i
done

#loop for reprocessing with BEAM optimization
for j in $(seq -f "%02g" 1 $beam_reproc); do
	echo; echo "####################################################";echo
	echo "Reprocessing with REFINED VALUES FOR BEAM DIVERGENCE AND MOSAICITY: Cycle $j of $(printf %02d $beam_reproc)";echo
	repro_BEAM $j
	stats $j
	copyFiles BEAM_$j
done


#Move log file to reprocess folder
mv Reprocessing.log reprocess/ 
echo "Reprocessing finished";echo


#compare correct file
echo "Comparing CORRECT.LP files";echo
vimdiff reprocess/CORRECT.LP_ini reprocess/CORRECT.LP_repro_$i reprocess/CORRECT.LP_BEAM_$j
