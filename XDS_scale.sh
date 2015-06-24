#!/bin/bash

#Exit after first nonzero exit code
set -e

#script to run xscale and xdsconv after data processing

# functions

#function to display intro
function intro {
	echo
	echo "******************************************************************"
	echo
	echo "This bash script runs XSCALE and XDSCONV to creates an MTZ file"
	echo
	echo "******************************************************************"
	echo
}

#function to get resolution shells from CORRECT.LP
function res_shells {
	echo -e "\n\tGetting Resolution shells from CORRECT.LP \n"
	egrep -B 25 "WILSON STATISTICS OF DATA SET" CORRECT.LP | egrep -A 14  "SUBSET OF INTENSITY DATA WITH SIGNAL/NOISE" |sed -n '5,13p' | awk '{print $1}' > stats1.txt
	res_shells="$(paste -d " "  -s stats1.txt)"
	rm stats1.txt
	echo -e "\tResolution shells: $res_shells"
	echo "RESOLUTION_SHELLS=$res_shells" >XSCALE.INP
}

#get stats table from XSCALE.LP
function getStats {
	echo "Scaling statistics from XSCALE.LP";echo
	egrep -A $res  "SUBSET OF INTENSITY DATA WITH SIGNAL/NOISE" XSCALE.LP
	egrep -B 2 -A 2 "REFLECTIONS REJECTED" XSCALE.LP
}

#get stats table from CORRECT.LP
#function to get scaling statisticss table
function statsCorrect {
	echo "Scaling statistics from CORRECT.LP";echo
	egrep -B 25 "WILSON STATISTICS OF DATA SET" CORRECT.LP | egrep -A 21  "SUBSET OF INTENSITY DATA WITH SIGNAL/NOISE"
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

#function to get output file name

############

# Running Scriot 

###############
#clear screen
clear

intro
 
#Ask user for output file name
output=
while [[ $output = "" ]]; do
	echo -n "Output file name (e.g. SCH0312.mtz): " 
	read output
done

#move current xscale
if [ -e XSCALE.INP ]; then
	mv XSCALE.INP  XSCALE.INP_"$(date +%m_%d_%Y_%T)"
fi

#move XDSCONV file
if [ -e XDSCONV.INP ]; then 
	mv XDSCONV.INP XDSCONV.INP_"$(date +%m_%d_%Y_%T)"
fi

#Get resolution shells
if askuser "Get resolution shells from CORRECT.LP (10) or used default (20)? (Y/N) " YyNn Yy Nn; then
	res_shells
	res=15
else
	echo;echo -e "\tUsing 20 resolution shells (XSCALE Default)"
	res=26
fi

#Add output file to XSCALE.LP
echo "OUTPUT_FILE=temp.ahkl" >>XSCALE.INP

#Get Friedel's Law
if askuser "Is Friedel's law True or False? (T/F)" TtFf Tt Ff; then
	echo;echo -e "\tFriedels's law is true"
	echo "FRIEDEL'S_LAW=TRUE" >>XSCALE.INP
	echo "FRIEDEL'S_LAW=TRUE" >>XDSCONV.INP
else
	echo;echo -e "\tFriedel's law is false"
	echo "FRIEDEL'S_LAW=FALSE" >>XSCALE.INP
	echo "FRIEDEL'S_LAW=FALSE" >>XDSCONV.INP
fi

#Get merge 
if askuser "Merge symmetry equivalent reflections? (T/F)" TtFf Tt Ff; then
	echo;echo -e "\tMerging symmetry equivalent reflections"
	echo "MERGE=TRUE" >>XSCALE.INP
	echo "MERGE=TRUE" >>XDSCONV.INP
else
	echo;echo -e "\tNot merging symmetry equivalent reflections"
	echo "MERGE=FALSE" >>XSCALE.INP
	echo "MERGE=FALSE" >>XDSCONV.INP
fi

#Get strict absorption correnction
if askuser "Use strict absorption correction? (T/F)" TtFf Tt Ff; then
	echo;echo -e "\tUsing strict absorption correction?"
	echo "STRICT_ABSORPTION_CORRECTION=TRUE" >>XSCALE.INP
else
	echo;echo -e "\tNot using strict absorption correction"
fi

#Get input file
echo "INPUT_FILE= XDS_ASCII.HKL" >>XSCALE.INP

#get crystal name
if askuser "Use 0-dose extrapolation? (T/F)" TtFf Tt Ff; then
	echo;echo -e "\tUsing 0-dose extrapolation"
	 
	 #Ask user for crystal name
	  crystalName=
	  while [[ $crystalName = "" ]];do
		  echo;echo -n "What is the crystal's name? (eg SCH0312): " 
		  read crystalName
	 done

	echo "CRYSTAL_NAME="$crystalName"" >>XSCALE.INP
else
	echo;echo -e "\tNot using 0-dose extrapolation"
fi

#run xscale
echo; echo "Running XSCALE";echo
xscale > xscale.log 

echo "########################################################";echo
#Display stats from correct and xscale
statsCorrect
echo "*************************";echo
getStats
echo "########################################################";echo

#get more info for XDSCON

if askuser "Continue to XDSCONV? (T/F)" TtFf Tt Ff; then
	echo;echo -e "\tContinuing to XDSCONV";echo
else 
	echo;echo "Terminating script";echo
	exit 1
fi

# add xdsconv input file 
echo "INPUT_FILE=temp.ahkl" >> XDSCONV.INP

#Ask user for output format 
for_test="fail"
while [[ "$for_test" = "fail" ]]; do
	echo -e "\nXDS can output the following MTZ file formats \n 
	1.\tCCP4\tamplitudes and their anomalous differences for the CCP4 package\n
	2.\tCCP4_F\tamplitudes {F,F(+),F(-)} for the CCP4 package\n
	3.\tCCP4_I\tintensities {IMEAN,I(+),I(-)} for use by CCP4's 'truncate'\n"

	echo -n "Which format would you like? [1-3]: "
	read -r -n 1 -s u_format
	case $u_format in

    	    1) echo -e "\n\n\tCCP4 format"; 
				format="CCP4"
				for_test="pass"
        	        ;;

    	    2) echo -e "\n\n\tCCP4_F format"; 
				format="CCP4_F"
				for_test="pass"
        	        ;;

    	    3) echo -e "\n\n\tCCP4_I format"; 
				format="CCP4_I"
				for_test="pass"
        	        ;;

			*) echo -e "\n\n\t Invalid input"
					for_test="fail"
					;;
	esac
done

echo "OUTPUT_FILE=temp.hkl $format" >> XDSCONV.INP

#Ask user about test set
if askuser "Mark 5% of the data as FreeR set? (T/F): " TtFf Tt Ff; then
	echo;echo -e  "\tCreating FreeR set"
	echo "GENERATE_FRACTION_OF_TEST_REFLECTIONS=0.05" >> XDSCONV.INP
else
	echo;echo -e "\t Not creating a FreeR set"
fi

#run xdsconv
echo -e "\n\nRunning XDSCONV"

xdsconv > xdsconv.log

#converting to MTZ
f2mtz HKLOUT temp.mtz<F2MTZ.INP >f2mtz.log
cad HKLIN1 temp.mtz HKLOUT $output<<EOF > cad.log
 LABIN FILE 1 ALL
 END
EOF

echo -e "\nCreated $output"
echo -e "\nScaling and converting done\n"
