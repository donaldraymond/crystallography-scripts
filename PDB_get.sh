#! /bin/bash

#Exit after first nonzero exit code
set -e

#get pdb id from user
if [[ $# == 0 ]] || [[ ${#1} != 4 ]]; then
	echo; read -p "Please enter a valid PDB ID (e.g. 1yks): " -n 4 -e pdb_id
else
	pdb_id="$1"
fi

#get pdb file pro
echo -e "\nGetting $pdb_id coordinate file from PDB\n"
curl -O -sf "http://www.rcsb.org/pdb/files/"$pdb_id".pdb"

#end
if [[ "$?" != "0" ]] ; then
    echo -e "Could not download the PDB file. Please check PDB ID and/or online status\n"
else
	echo -e "Download complete!!\n"
fi
