#!/bin/bash

#script to download files from PDB
#written by Donald Raymond (Steve Harrison Lab)
#email me at raymond [at] crystal.harvard.edu

#January 12 2015 - Initial release
#January 14 2015 - Added feature to take parameter
#January 20 2015 - Added feature to deal with intensities
#January 22 2015 - Added checks to deal with duplicates in cif file

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

#############################
#
#Functions
#
#############################

#function to download file
function get_file {
curl -O -sf "http://www.rcsb.org/pdb/files/"$pdb_id""$1""
}

#function to get cell dimensions
function get_cell {
awk "/_cell."$1"/ {print \$2;exit}" "$cif_file"
}

#function to get resolution
function get_res {
grep "$1" $pdb_file | awk -F ":" '{print $2;exit}' | awk '{ gsub (" ", "", $0); print}'
}

#function to make mtz
function make_mtz {
echo -e "\nConverting mmCIF to MTZ"
cif2mtz  HKLIN $cif_file HKLOUT temp.mtz << eof > /dev/null
SYMMETRY "$space_group"
END
eof
}

#function to convert intensities to amplitudes
function int_amp {
#Convert I to F
echo -e "\nConverting intensities to amplitudes"
truncate="$CCP4/bin/truncate"
$truncate HKLIN "temp.mtz" HKLOUT "temp1.mtz" << eof > /dev/null
truncate YES
anomalous NO
nresidue 888
plot OFF
header BRIEF BATCH
labin IMEAN=I SIGIMEAN=SIGI  FreeR_flag=FREE
labout F=FP SIGF=SIGFP FreeR_flag=FREE
falloff yes
NOHARVEST
end
eof

mv temp1.mtz temp.mtz
}

#function to calculate map coefficients
function calc_mapcoef {
echo -e "\nCalculating structure factors and map coefficients"
refmac5 XYZIN "$pdb_file" XYZOUT temp.pdb HKLIN temp.mtz HKLOUT $pdb_id.mtz << eof > /dev/null
labin  FP=FP SIGFP=SIGFP FREE=FREE
ncyc 0
labout  FC=FC FWT=FWT PHIC=PHIC PHWT=PHWT DELFWT=DELFWT PHDELWT=PHDELWT FOM=FOM
RSIZE 80
END
eof
}

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
if [[ $# == 0 ]] || [[ ${#1} != 4 ]]; then
	read -p "Please enter a valid PDB ID (e.g. 1yks): " -n 4 -e pdb_id
else
	pdb_id="$1"
fi

#get cif-file from PDB
echo -e "Getting $pdb_id structure factor file from PDB\n"
get_file "-sf.cif"

#if cannot download the file, end script
if [[ "$?" != "0" ]] ; then
    echo -e "Could not download the cif file. Please check PDB ID and/or online status\n"
    exit 1
fi
cif_file="$pdb_id-sf.cif"

#get pdb file pro
echo -e "Getting $pdb_id coordinate file from PDB\n"
get_file ".pdb"
pdb_file="$pdb_id.pdb"

#get unit cells constants
a=$(get_cell "length_a")
b=$(get_cell "length_b")
c=$(get_cell "length_c")
alpha=$(get_cell "angle_alpha")
beta=$(get_cell "angle_beta")
gamma=$(get_cell "angle_gamma")

echo -e "Unit cell constants are: $a $b $c $alpha $beta $gamma"

#get space group
space_group=`grep "symmetry.space_group_name" $cif_file | awk -F "['\"]" '{print $2;exit}' | awk '{ gsub (" ", "", $0); print}'`

echo -e "\nSpace group is: $space_group"

#get resolution
high_res=$(get_res "RESOLUTION RANGE HIGH (ANGSTROMS)")
low_res=$(get_res "RESOLUTION RANGE LOW  (ANGSTROMS)")

echo -e "\nResolution is: $low_res  $high_res "

#Convert mmCIF to MTZ
make_mtz

#check to see if data are in intensities or amplitudes
if ! grep -q "_refln.F_meas_au" $cif_file && grep -q "_refln.intensity_meas" $cif_file; then
#Convert I to F
int_amp
fi

#Calculate phases
calc_mapcoef 

#cleanup
rm temp* "$cif_file" 2> /dev/null

#end
echo -e "\nScript DONE!!\n"