#!/bin/bash

#This is a script to calculate structure factors and map coefficients

#for debugging
#set -x

#clear screen
clear
##################################################################

#check if refmac5 is installed
if hash refmac5 2>/dev/null; then
	echo -e "\nFound refmac5...continuing with script"
else
	echo -e "\nrefmac5 is required to run this script\n"
	exit 1
fi

#function to calculate map coefficients
function calc_mapcoef {
#make unique temp PDB file
tempPDB=_temp$$.pdb
echo -e "\nCalculating structure factors and map coefficients"
refmac5 XYZIN "$pdbfile" XYZOUT $tempPDB HKLIN $mtzfile HKLOUT `basename $mtzfile .mtz`_maps.mtz << eof > refmac.log
labin  FP=FP SIGFP=SIGFP FREE=FreeRflag 
ncyc 0
labout  FC=FC FWT=FWT PHIC=PHIC PHWT=PHWT DELFWT=DELFWT PHDELWT=PHDELWT FOM=FOM
RSIZE 80
END
eof

#get R and R_free from refmac
echo -e "\nR/R_free:`awk '/^       0   0/ {print $2}' refmac.log`/`awk '/^       0   0/ {print $3}' refmac.log`" #$r_fac/$r_free

#remove refmac.log
rm $tempPDB refmac.log 2> /dev/null
}

# scan command line for user-specified pdb and mtz
for arg in "$@" 
do
	if [[ "$arg" = *.pdb ]] ; then 
		pdbfile="$arg"
	fi

	if [[ "$arg" = *.mtz ]] ; then
		mtzfile="$arg"
	fi
done

#check for pdb or mtz files
if ! [ -e "$pdbfile" ] || ! [ -e "$mtzfile" ] ; then
	echo -e "\nNo PDB or MTZ file specified\n"
	exit 1
fi

#calculate map coefficients
calc_mapcoef

#Exit script 
echo -e "\nScript done\n"
