#!/bin/bash

#######################################################

# This is a script will process Multiple datasets in a folder
# Written by Donald Raymond (draymond@broadinstitute.org)

#last_update="January 26 2019"

#######################################################

#for debugging 
#set -x

#check if xds and pointless are installed
if hash xds_par 2>/dev/null && hash pointless 2>/dev/null; then
	echo -e "\nFound xds and pointless...continuing with script"
else
	echo -e "\nThis script requires XDS and Pointless\n"
	exit 1
fi

#clear screen
clear

#Functions
#function to display intro
function intro {
	echo
	echo "**************************************************************************"
	echo
	echo "This bash script will  process all X-ray diffraction Datasets in a folder "
	echo
	echo "**************************************************************************"
	echo
}

#function to ask for user input

function askuser {
echo;echo -n "$1 "
while read -r -n 1 -s answer; do
  if [[ $answer = [$2] ]]; then
    [[ $answer = [$3] ]] && retval=0
    [[ $answer = [$4] ]] && retval=1
    break
  fi  
done
echo # just a final linefeed, optics...

return $retval
}

#Begin Script 

#time at beginnig of script
begin=$(date +"%s")

intro 

#move current summary file
if [ -e "ProcessingSummary.txt" ]; then
	mv "ProcessingSummary.txt" 2> ProcessingSummary.txt_`date '+%Y%m%d_%H_%M_%S'`
	touch "ProcessingSummary.txt"
else
	touch "ProcessingSummary.txt"
fi

# Add intro to Summary file

echo -e "\n\n \tData Processing Summary\n\n" >> ProcessingSummary.txt

#Ask about Project
projectName=
while [[ $projectName = "" ]];do
	echo;echo -n "What is the Project name? (eg RVFV): " 
	read projectName
done

echo -e "\n\tProject is $projectName"

#Ask about XDS or DIALS
if askuser "Use XDS (X) or DIALS (D)" XxDd Xx Dd; then
	echo -e "\n\t Using XDS to process data"
	prog=3d
else 
	echo -e "\n\t Using DIALS to process data"
	prog=dials
fi

#Enforce spacegroup
#get crystal name
if askuser "Enforce a specific spacegroup (T/F)?" TtFf Tt Ff; then
	echo -e "\n\tEnforcing Spacegroup"
	 
	 #Ask user for crystal name
	  spaceGroup=
	  while [[ $spaceGroup = "" ]];do
		  echo;echo -n "What is the Spacegroup? (eg P61): " 
		  read spaceGroup
	 done

	echo -e "\n\tUsing $spaceGroup for all Datasets"
else
	echo -e "\n\tNot Enforcing Spacegroup"
	spaceGroup="NONE"
fi 

#get directory of images from user
for arg in "$1" 
do
	if [[ -n "$arg" ]] ; then 
		ImageFolder=$arg
		ImageFolder=${1%/}
		echo -e "\nDatasets are located in $ImageFolder \n" 

	else [[ -z "$arg" ]] 
		echo -e "\nNo image folder provided, ending script \n"
		exit 0
	fi
done

#Process data in each folder
for dir in $ImageFolder/*; do
	# check if file is a folder
	[ -d "$dir" ] || continue

	#find a folder containing at least 50 cbg or IMG files
	container=`find $dir -type f \( -name "*50.cbf" -o -name "*50.CBF" -name "*50.img" -o -name "*50.IMG" \) -print -quit | xargs dirname 2>/dev/null`
	
	# Confirm cbf files
	count_cbf=`ls -1 $container/*.cbf 2>/dev/null | wc -l`
	count_img=`ls -1 $container/*.img 2>/dev/null | wc -l`
	if [ $count_cbf != "0" ] || [ $count_img != "0" ] && [ ! -f CORRECT.LP ] ; then
		echo -e "Processing files in $dir \n"
		echo -e "Found $count_cbf CBF and $count_img IMG files in $container\n"
	
		#get folder basename
		crystal=`basename $dir`

		# Run Xia2
	 	xia2 pipeline=$prog project=$projectName space_group=$spaceGroup min_images=200 crystal=$crystal $container 


			
		#Get Summary for Table 1
		
		if [ -e xia2-summary.dat ]; then
			cat xia2-summary.dat >> ProcessingSummary.txt
		
		else
			echo -e "\n\t Processing $crystal failed. See $crystal/xia2-debug.txt for more information. \n" >> ProcessingSummary.txt
		fi

		# spacing
		echo -e "\n********************************************************************************************************************" >> ProcessingSummary.txt
		echo -e "********************************************************************************************************************\n" >> ProcessingSummary.txt
		
		#dealing with logs and Datafile directory
		mv xia2* $crystal 2>/dev/null
		mv automatic.xinfo $crystal 2>/dev/null
		mv DataFiles $crystal 2>/dev/null

		# Run phenix pipeline to phase and refine model
		#phenix.ligand_pipeline model.pdb ""$crystal"/DataFiles/"$projectName"_"$crystal"_free.mtz" nproc=12 skip_ligand=true mr=true copies=2 build=False refine.after_mr.cycles=3 refine.after_mr.optimize_weights=True refine.after_mr.real_space=False refine.after_mr.update_waters=False prune=False refine_after_fitting=False 

		#move phenix pipeline files to appropriate folder
		#mv pipeline* $crystal 2>/dev/null

		echo -e "\n Moving to new dataset \n"
		echo -e "\n#####################################################################################################"
		echo -e "#####################################################################################################\n"
	fi
done

# Endscript

termin=$(date +"%s")
difftimelps=$(($termin-$begin))

echo -e "Data processing finished. Total time:$(($difftimelps / 60)) minutes and $(($difftimelps % 60)) seconds.\n"
