#!/bin/bash

#script to download files from PDB
#written by Donald Raymond (Steve Harrison Lab)
#email me at raymond [at] crystal.harvard.edu

#January 12 2015 - Initial release
#January 14 2015 - Added feature to take parameter

#for debugging
#set -x
##################################################################

#check if cif2mtz and refmac5 are installed
if hash cif2mtz 2>/dev/null && hash refmac5 2>/dev/null; then
	echo -e "\nFound cif2mtz and refmac5...continuing with script"
else
	echo -e "\ncif2mtz and refmac5 are required to run this script\n"
	exit 1
fi

#clear screen
clear

# script info
echo '
************************************************************************

This script will get mmCIF and PDB files from the Protein Data Bank

It will then convert the mmCIF to an MTZ file and calculate phases

************************************************************************
'

#get pdb id from user
if [[ $# == 0 ]]; then
	read -p "Please enter a valid PDB ID (e.g. 1yks): " -n 4 -e pdb_id
else
	pdb_id="$1"
fi

#get cif-file from PDB
echo -e "\nGetting $pdb_id structure factor file from PDB\n"
curl -O -f "http://www.pdb.org/pdb/files/$pdb_id-sf.cif"

#if cannot download the file, end script
if [[ "$?" != "0" ]] ; then
    echo -e "\nCould not download the cif file. Please check PDB ID and/or online status\n"
    exit 1
fi
cif_file="$pdb_id-sf.cif"

#get pdb file pro
echo -e "\nGetting $pdb_id coordinate file from PDB\n"
curl -O -f "http://www.pdb.org/pdb/files/$pdb_id.pdb"
pdb_file="$pdb_id.pdb"

#get unit cells constants
a=`awk '/_cell.length_a/ {print $2}' "$cif_file"`
b=`awk '/_cell.length_b/ {print $2}' "$cif_file"`
c=`awk '/_cell.length_c/ {print $2}' "$cif_file"`
alpha=`awk '/_cell.angle_alpha/ {print $2}' "$cif_file"`
beta=`awk '/_cell.angle_beta/ {print $2}' "$cif_file"`
gamma=`awk '/_cell.angle_gamma/ {print $2}' "$cif_file"`

echo -e "\nUnit cell constants are: $a $b $c $alpha $beta $gamma"

#get space group
space_group=`grep "symmetry.space_group_name" $cif_file | awk -F "['\"]" '{print $2}' | awk '{ gsub (" ", "", $0); print}'`

echo -e "\nSpace group is: $space_group"

#get resolution
high_res=`grep "RESOLUTION RANGE HIGH (ANGSTROMS)" $pdb_file | awk -F ":" '{print $2}' | awk '{ gsub (" ", "", $0); print}'`
low_res=`grep "RESOLUTION RANGE LOW  (ANGSTROMS)" $pdb_file | awk -F ":" '{print $2}'  | awk '{ gsub (" ", "", $0); print}'`

echo -e "\nResolution is: $low_res  $high_res "

#Convert mmCIF to MTZ
echo -e "\nConverting mmCIF to MTZ"
cif2mtz  HKLIN $cif_file HKLOUT temp.mtz << eof > /dev/null
SYMMETRY $space_group
END
eof

#Calculate phases
echo -e "\nCalculating structure factors and map coefficients"
refmac5 XYZIN "$pdb_file" XYZOUT temp.pdb HKLIN temp.mtz HKLOUT $pdb_id.mtz << eof > /dev/null
labin  FP=FP SIGFP=SIGFP FREE=FREE
ncyc 0
labout  FC=FC FWT=FWT PHIC=PHIC PHWT=PHWT DELFWT=DELFWT PHDELWT=PHDELWT FOM=FOM
RSIZE 80
END
eof

#cleanup
rm temp.* "$cif_file" 2> /dev/null

#end
echo -e "\nScript DONE!!\n"
