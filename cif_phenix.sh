#!/bin/bash

#script to generate ligand cif files
#written by Donald Raymond (March 30 2018)

########################################################

#check if phenix is installed
if hash phenix 2>/dev/null; then
	echo -e "\nFound Grade...continuing with script"
else
	echo -e "\nGrade is required to run this script\n"
	exit 1
fi

#clear screen
clear

echo '
***************************************************************
This script will generate ligand cif files for refinement
***************************************************************
'
#Function to Ask user for information 1-prompt; 2- number of characters
function ask {
 read -p "$1"": " -n $2 -e val
 echo $val
}

#get SMILES string
SMILES_string_entered=$(ask "Insert SMILES string" 1000)

#remove spaces, tabs ,etc from SMILES string
SMILES_string=${SMILES_string_entered//[[:blank:]]/}
echo

#get ligand name 
ligandID=$(ask "What is the ligand ID? (3 character)" 3)
echo

#get file name
fileName_entered=$(ask "filename" 20)

#remove spaces, tabs ,etc from file name
fileName=${fileName_entered//[[:blank:]]/}
echo

echo "The SMILES string is $SMILES_string" ;echo

echo "The ligand ID is $ligandID" ;echo

echo "The file name is $fileName.cif" ;echo

#run elbow
#Grade cif file
phenix.elbow --smiles=$SMILES_string --id=$ligandID --output=$fileName --opt

#clean up
rm *.xyz *.pickle

echo; echo "End Script"

echo

