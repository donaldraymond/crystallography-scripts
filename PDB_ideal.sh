#!/bin/bash

# This is a scrip to idealize a model using refmac5

#for debugging
#set -x

#clear screen
clear

#check if refmac5 is installed
if hash refmac5 2>/dev/null; then
	echo -e "\nFound refmac5...continuing with script\n"
else
	echo -e "\nrefmac5 is required to run this script\n"
	exit 1
fi

if [[ "$1" = *.pdb ]] ;then
	pdbin=`basename $1 .pdb`
	echo -e "PDB is "$1""
else 
	echo -e "Invalid input or no PDB specified\n"
	exit 1
fi

#Function to get number of cycles
function get_number {
numbers=""
while ! [ "$number" -eq "$number" ] 2> /dev/null || [ "$number" -lt "1" ] 2> /dev/null ; do
	echo -ne "\nNumber of cycles: "
    read number
done
echo -e "\nRunning $number cycles\n"
}

#function to run refmac idealized
function idealize {
refmac5 XYZIN "$pdbin.pdb" XYZOUT "$pdbin"_ideal.pdb << eof
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
