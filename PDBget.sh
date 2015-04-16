#! /bin/bash

#function to download file
function get_file {
curl -O -f "http://www.rcsb.org/pdb/files/"$pdb_id""$1""
}

#get pdb id from user
if [[ $# == 0 ]] || [[ ${#1} != 4 ]]; then
	echo; read -p "Please enter a valid PDB ID (e.g. 1yks): " -n 4 -e pdb_id
else
	pdb_id="$1"
fi

#get pdb file pro
echo -e "\nGetting $pdb_id coordinate file from PDB\n"
get_file ".pdb"
#pdb_file="$pdb_id.pdb"

#end
echo -e "\nScript DONE!!\n"
