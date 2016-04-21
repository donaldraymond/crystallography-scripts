#! /bin/bash

#get pdb id from user
if [[ $# == 0 ]] || [[ ${#1} != 4 ]]; then
	echo; read -p "Please enter a valid PDB ID (e.g. 1yks): " -n 4 -e pdb_id
else
	pdb_id="$1"
fi

#get pdb file pro
echo -e "\nGetting $pdb_id coordinate file from PDB\n"
curl -O -sf "http://files.rcsb.org/view/"$pdb_id".pdb"

#check if file downloaded
if [ ! -f ""$pdb_id".pdb" ]; then
	echo -e "Could not download the PDB file. Please check PDB ID and/or online status\n"
	exit 1
else
	echo -e "Download complete!!\n"
fi

#end
