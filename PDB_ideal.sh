#!/bin/bash

# This is a scrip to idealize a model using refmac5

#for debugging
#set -x

#clear screen
clear

#check is sftools and fft are installed
if hash refmac5 2>/dev/null; then
	echo -e "\nFound refmac5...continuing with script\n"
else
	echo -e "\nrefmac5 is required to run this script\n"
	exit 1
fi

if [[ "$1" = *.pdb ]] ;then
	pdbin=$1
	echo -e "PDB is $pdbin\n"
else 
	echo -e "Invalid input or no PDB specified\n"
fi

#Function to get number of cycles
function get_number {
check="fail"
while [[ "$check" = "fail" ]]; do
	echo -n "Number of cycles: "
    read number

    if ! [ "$number" -eq "$number" ] 2> /dev/null || [ "$number" -lt "0" ] 2> /dev/null; then
        echo -e "\nInvalid input\n"
    else 
        echo -e "\nRunning $number cycles"
        check="pass"
    fi  
done
echo
}

#function to run refmac idealized
function idealize {
refmac5 XYZIN "$pdbin" XYZOUT idealized_$pdbin << eof
make -
    hydrogen ALL -
    hout NO -
    peptide NO -
    cispeptide YES -
    ssbridge YES -
    symmetry YES -
    sugar YES -
    connectivity NO -
    link NO
NCSR LOCAL
refi -
    type IDEA -
    resi MLKF -
    meth CGMAT -
    bref over
ncyc $number
scal -
    type SIMP -
    LSSC -
    ANISO -
    EXPE
solvent YES
weight -
    AUTO
monitor MEDIUM -
    torsion 10.0 -
    distance 10.0 -
    angle 10.0 -
    plane 10.0 -
    chiral 10.0 -
    bfactor 10.0 -
    bsphere 10.0 -
    rbond 10.0 -
    ncsr 10.0
RSIZE 80
EXTERNAL WEIGHT SCALE 10.0
EXTERNAL USE MAIN
EXTERNAL DMAX 4.2
END
eof
}

#Get number of cycles
get_number

#Run function to idealize PDB
idealize 

#Finish script
echo -e "\nEnd of Script\n"
