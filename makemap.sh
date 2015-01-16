#!/bin/bash

#######################################################

# This is a script to create ccp4 maps for O, PyMOL or COOT
#written by Donald Raymond
#List of changes
#12/19/14 initial release
#01/14/15 Bug fix

last_update="January 14 2015"

#######################################################

#clear screen
clear

#function to make map 1:input file 2:output file 3:low res 4:high res 5:F 6:phase
function make_map {
fft HKLIN $1 MAPOUT $2 << eof > /dev/null
xyzlim asu
resolution $3 $4
GRID SAMPLE 6.0
labin F1=$5 PHI=$6
end
eof

# normalize the map
mapmask mapin $2  mapout $2  << EOF > /dev/null
SCALE SIGMA
EOF
}

#function to get space group name
function spacegroup {
 grep "Space group name" sftoolsread.txt | awk -F ":" '{print $2}' | awk '{ gsub (" ", "", $0); print}'
}

# Echo purpose of script
echo -e "\n"
echo -e "*********************************************************************"
echo -e
echo -e "This is a script to produce CCP4 maps for viewing in O, PyMOL or COOT"
echo -e
echo -e "Updated on $last_update by Donald Raymond (Steve Harrison Lab)"
echo -e
echo -e "*********************************************************************"


#check to see if user specified a file
if  [ -f "$1" ] && [[ "$1" = *.mtz ]] ;then
	echo -e "\nFound $1"
	filename=$1
else
	filename="null"
	while [ ! -f "$filename" ]; do
		echo -e "\nList of MTZ files in the current directory\n"
		echo -e "*********************\n"
 		echo -e "`ls *.mtz 2>/dev/null`\n"
		echo -e "*********************\n"
		read -p "Please enter a valid MTZ filename (e.g. file.mtz): " filename

		if [ ! -f "$filename" ]; then
			echo -e "\nCould not find an MTZ file called $filename"
		fi

	done
	echo -e "\nFound $filename"
fi

echo -e "\nRunning sftools"
#read file in sftools
#sftools <<EOF > sftoolsread.txt
sftools <<EOF | tee sftoolsread.txt
 read $filename
 complete
 list
 quit
EOF


#get the resolution 
echo -e "\nGetting resolution limits"
res_low="`awk '/The resolution range in the data base is/ {print $9}' sftoolsread.txt`"
echo -e "\n\tLow resolution limit is $res_low"

res_high="`awk '/The resolution range in the data base is/ {print $11}' sftoolsread.txt`"
echo -e "\n\tHigh resolution limit is $res_high\n"

#get space group name
spaceGroupName=$(spacegroup)
echo -e "The space group is $spaceGroupName \n"

#Find map coefficients
echo -e "Finding map coefficients\n"

if  $(grep -q FDM sftoolsread.txt); then
    echo -e "\tDM map coefficients found\n"
	map_coef=FDM
elif  $(grep -q FEM sftoolsread.txt); then
    echo -e "\tFEM map coefficients found\n"
	map_coef=FEM
elif  $(grep -q FWT sftoolsread.txt) && $(grep -q DELFWT sftoolsread.txt); then
    echo -e "\t2FoFc and FoFc map coefficients found\n"
	map_coef=F_DELWT
elif  $(grep -q FWT sftoolsread.txt); then
    echo -e "\tmap coefficients found\n"
	map_coef=FWT
elif  $(grep -q 2FOFCWT sftoolsread.txt); then
    echo -e "\t2FoFc and FoFc map coefficients found\n"
	map_coef=2FO
else
	echo -e "\tNo known map coefficients found\n\n\tSend mtz to raymond@crystal.harvard.edu to update this script\n"
	exit
fi

#Ask user for map prefix
mapName=
while [[ $mapName = "" ]];do
	echo -n "Prefix for output map file: " 
	read mapName
done

#make map
echo -e "\nMaking and normalizing map(s)"
case $map_coef in 
	F_DELWT) 	make_map $filename $mapName-2FoFc.ccp4 $res_low $res_high FWT PHWT 
				make_map $filename $mapName-FoFc.ccp4 $res_low $res_high DELFWT PHDELWT
				echo -e "\n\tCreated $mapName-2FoFc.ccp4 and $mapName-FoFc.ccp4"
					;;
	
	FDM)		make_map $filename $mapName-DM.ccp4 $res_low $res_high FDM PHIDM
				echo -e "\n\tCreated $mapName-DM.ccp4"
					;;

	FEM)		make_map $filename $mapName-FEM.ccp4 $res_low $res_high FEM PHIFEM 
				echo -e "\n\tCreated $mapName-FEM.ccp4"
					;;
	
	FWT)		make_map $filename $mapName.ccp4 $res_low $res_high FWT 
				echo -e "\n\tCreated $mapName.ccp4"
					;;
	
	2FO)		make_map $filename $mapName-2FoFc.ccp4 $res_low $res_high 2FOFCWT PH2FOFCWT
				make_map $filename $mapName-FoFc.ccp4 $res_low $res_high FOFCWT PHFOFCWT 
				echo -e "\n\tCreated $mapName-2FoFc.ccp4 and $mapName-FoFc.ccp4"
					;;

	*)			echo -e "\nUnknow map coefficients labels"
				echo -e "Please send MTZ to raymond@crystal.harvard.edu to update script"
					;;
esac
 
rm -rf sftoolsread.txt 2> /dev/null

#Finish script
echo -e "\nScript finished\n"
