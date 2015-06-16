#!/bin/bash

#######################################################

# This is a script to create ccp4 maps for O, PyMOL or COOT
#written by Donald Raymond

last_update="June 15 2015"

#######################################################
#for debugging 
#set -x

#check if sftools and fft are installed
if hash sftools 2>/dev/null && hash fft 2>/dev/null; then
	echo -e "\nFound sftools and fft...continuing with script"
else
	echo -e "\nThis script requires sftools and fft\n"
	exit 1
fi

#clear screen
clear

###############################
#
# Functions
#
###############################

#function to run sftools
function read_mtz {
#read file in sftools
sftools <<EOF | tee sftoolsread.txt
 read $mtzfile
 complete
 list
 end
 yes
EOF
}

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

#Function to query user
function askuser {
echo;echo -n "$1 "
while read -r -n 1 -s answer; do
  if [[ $answer = [$2] ]]; then
    [[ $answer = [$3] ]] && retval=0
	[[ $answer = [$4] ]] && retval=1
	break
  fi  
done
echo
return $retval
}

#function to check for custom F and P
function check_cus {
	if grep -q "$1\s*$2" sftoolsread.txt; then
		echo -e "\nFound $2\n"
	else
		echo -e "\nDid not find $2\n"
		exit 1
	fi
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
	mtzfile=$1
else
	if [[ -z "$mtzfile" ]]; then
		echo -e "\nMTZs in current directory: `ls -m  *.mtz 2>/dev/null` \n"
		read -p "Load MTZ file: " mtzfile
		while [ ! -f "$mtzfile" ]; do
			echo
			read -p "I need a valid MTZ file: " mtzfile
		done
		echo -e "\nFound $mtzfile"
	fi
fi

echo -e "\nRunning sftools"
read_mtz

#Find map coefficients
echo -e "\nFinding map coefficients\n"

if  $(grep -q FDM sftoolsread.txt); then
    echo -e "\tDM map coefficients found\n"
	map_coef=FDM
elif  $(grep -q FEM sftoolsread.txt); then
    echo -e "\tFEM map coefficients found\n"
	map_coef=FEM
elif  $(grep -q 'parrot.F_phi.F' sftoolsread.txt); then
    echo -e "\tParrot map coefficients found\n"
	map_coef=PARROT
elif  $(grep -q FWT sftoolsread.txt) && $(grep -q DELFWT sftoolsread.txt); then
    echo -e "\t2FoFc and FoFc map coefficients found\n"
	map_coef=F_DELWT
elif  $(grep -q FWT sftoolsread.txt); then
    echo -e "\tmap coefficients found\n"
	map_coef=FWT
elif  $(grep -q PH2FOFCWT sftoolsread.txt) && $(grep -q PHFOFCWT sftoolsread.txt); then
    echo -e "\t2FoFc and FoFc map coefficients found\n"
	map_coef=2FO
elif $(grep -q PH2FOFCWT sftoolsread.txt) && ! $(grep -q PHFOFCWT sftoolsread.txt); then
    echo -e "\t2FoFc map coefficients found\n"
	map_coef=2FO_only
else
	#ask about custom F and P
	if askuser "Unknown coefficients...use custom F and P? (Y/N): " YyNn Yy Nn; then
		echo; read -p "Label of amplitude column: " amp
		check_cus F "$amp"

		read -p "Lable of phase column: " pha
		check_cus P "$pha"
		map_coef=custom
	else
		echo -e "\nTerminating script\n"
		exit 1
	fi
fi

#get the resolution 
echo -e "Getting resolution limits"
res_low="`awk '/The resolution range in the data base is/ {print $9}' sftoolsread.txt`"
echo -e "\n\tLow resolution limit is $res_low"

reso_high="`awk '/The resolution range in the data base is/ {print $11}' sftoolsread.txt`"
echo -e "\n\tHigh resolution limit is $reso_high\n"


#get space group name
spaceGroupName="`awk '/Initializing CHKHKL for spacegroup/ {print $5}' sftoolsread.txt`"
echo -e "The space group is $spaceGroupName \n"

#Ask user about lower resolution map
read -p "Resolution of map? [$reso_high] " res_high
while [[ -z "$res_high" ]] ; do
	res_high=$reso_high
done

#Ask user for map prefix
echo
read -p "Prefix for output map file [map]: " mapName
while [[ -z $mapName ]];do
	mapName=map
done

#make map
echo -e "\nMaking and normalizing map(s)"
case $map_coef in 
	F_DELWT) 	make_map $mtzfile $mapName-2FoFc.ccp4 $res_low $res_high FWT PHWT 
				make_map $mtzfile $mapName-FoFc.ccp4 $res_low $res_high DELFWT PHDELWT
				echo -e "\n\tCreated $mapName-2FoFc.ccp4 and $mapName-FoFc.ccp4"
					;;
	
	FDM)		make_map $mtzfile $mapName-DM.ccp4 $res_low $res_high FDM PHIDM
				echo -e "\n\tCreated $mapName-DM.ccp4"
					;;

	FEM)		make_map $mtzfile $mapName-FEM.ccp4 $res_low $res_high FEM PHIFEM 
				echo -e "\n\tCreated $mapName-FEM.ccp4"
					;;
	
	PARROT)		make_map $mtzfile $mapName-parrot.ccp4 $res_low $res_high 'parrot.F_phi.F' 'parrot.F_phi.phi' 
				echo -e "\n\tCreated $mapName-parrot.ccp4"
					;;
	
	FWT)		make_map $mtzfile $mapName.ccp4 $res_low $res_high FWT PHWT 
				echo -e "\n\tCreated $mapName.ccp4"
					;;
	
	2FO)		make_map $mtzfile $mapName-2FoFc.ccp4 $res_low $res_high 2FOFCWT PH2FOFCWT
				make_map $mtzfile $mapName-FoFc.ccp4 $res_low $res_high FOFCWT PHFOFCWT 
				echo -e "\n\tCreated $mapName-2FoFc.ccp4 and $mapName-FoFc.ccp4"
					;;
	
	2FO_only)	make_map $mtzfile $mapName-2FoFc.ccp4 $res_low $res_high 2FOFCWT PH2FOFCWT
				echo -e "\n\tCreated $mapName-2FoFc.ccp4"
					;;

	custom)		make_map $mtzfile $mapName.ccp4 $res_low $res_high $amp $pha 
				echo -e "\n\tCreated $mapName.ccp4"
					;;
	
	*)			echo -e "\nUnknow map coefficients labels"
				echo -e "Please send MTZ to raymond@crystal.harvard.edu to update script"
					;;
esac
 
rm -rf sftoolsread.txt 2> /dev/null

#Finish script
echo -e "\nScript finished\n"
