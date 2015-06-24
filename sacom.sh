#!/bin/bash

# This is a script to create a simulated annealing composite omit map

#Exit after first nonzero exit code
set -e

# for debugging
#set -x

#check if phenix.autobuild is installed
if hash phenix.autobuild 2>/dev/null; then
	echo -e "\nFound phenix.autobuild...continuing with script"
else
	echo -e "\nphenix.autobuild is required to run this script\n"
	exit 1
fi

# scan command line for user-specified pdb and mtz
for arg in "$@" 
do
	if [[ "$arg" = *.pdb ]] ; then 
		pdbfile="$arg"
	elif [[ "$arg" = *.mtz ]] ; then
		mtzfile="$arg"
	fi
done

#check for pdb or mtz files
if ! [ -e "$pdbfile" ] || ! [ -e "$mtzfile" ] ; then
	echo -e "\nNo PDB or MTZ file specified\n"
	exit 1
fi

#run phenix
echo -e "\n Files found...running Phenix\n"
phenix.autobuild data="$mtzfile" model="$pdbfile" composite_omit_type=sa_omit n_box_target=24 nproc=auto & 
