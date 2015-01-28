#!/bin/bash

#######################################################

# This is a script to create ccp4 maps for ono
#written by Donald Raymond (raymond@crystal.harvard.edu)

#List of changes
#12/19/14 initial release
#12/19/14 Added feature to create on_startup file to load maps into ono
#12/22/14 Added feature to find space group of map for redrawing in O
#01/03/14 Added feature to load PDB file
#01/03/15 Added feature to create O macro files
#01/05/15 Added feature to check for sftools and fft installations
#01/06/15 Added feature to create Duke stereochemistry database files
#01/08/15 Added feature to scan arguments for mtz and pdb inputs
#01/14/15 Added function to get pdb and mtz files
#01/19/15 Removed Duke stereochemistry files due to broken bonds
#01/22/15 Added feature to read old/residue_dict.odb
#01/23/14 Added feature to hide O files

last_update="January 23 2015"

#######################################################

#for begugging 
#set -x

#check is sftools and fft are installed
if hash sftools 2>/dev/null && hash fft 2>/dev/null; then
	echo -e "\nFound sftools and fft...continuing with script"
else
	echo -e "\nsftools and fft are required to run this script\n"
	exit 1
fi

#clear screen
clear

#list of variables
#variables to hold window positions
m_user="-1.66 0.56"
m_object="-1.66 0.94"
m_dial="1.44 -0.34"
m_paint="1.14 -0.34"

den1="1.06 0.98"
den2="1.06 0.65"
den3="1.06 0.32"
den4=""

###############################
#  FUNCTIONS
###############################

#function to run sftools
function read_mtz {
#read file in sftools
sftools <<EOF | tee sftoolsread.txt
 read $filename
 complete
 list
 quit
EOF
}

#function to get file 1:file, 2-file extension
function get_file {
loc_file="null"
if  [ -f "$1" ] ;then
	loc_file="$1"
	echo -e "\nFound $1"
else
	while [ ! -f "$loc_file" ]; do
		echo -e "\nList of $2 files in the current directory\n"
		echo -e "*********************\n"
 		echo -e "`ls *.$2 2> /dev/null`\n"
		echo -e "*********************\n"
		read -p "Please enter a valid $2 filename (e.g. file.$2): " loc_file

		if [ ! -f "$loc_file" ]; then
			echo -e "\nCould not find file called $loc_file"
		fi

	done
	echo -e "\nFound $loc_file"
fi
}

#function to make map 1:input file 2:output file 3:low res 4:high res 5:F 6:phase
function make_map {
#make the map
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

#function to add map to on_start
# $1-map file ; $2-map name; $3-sigma level; $4-color of electron density
# $5-density window number; $6-window position
function mapO {
	echo "fm_file $1 $2 $spaceGroupName" >> on_startup
	echo "Fm_setup $2 40 ; 1 $3 $4" >> on_startup
	echo "window_open density_$5 $6" >> on_startup
	echo >> on_startup
}

#function to get space group name
function spacegroup {
 grep "Space group name" sftoolsread.txt | awk -F ":" '{print $2}' | awk '{ gsub (" ", "", $0); print}'
}

#function to append map name to o_files
function redraw {
echo "fm_draw $1" >> $O_dir/next_water
echo "fm_draw $1" >> $O_dir/next_ca
echo "fm_draw $1" >> $O_dir/previous_ca
echo "fm_draw $1" >> $O_dir/redraw_map
}

# Echo purpose of script
echo -e "\n"
echo -e "******************************************************************"
echo -e
echo -e "This is a script to produce CCP4 maps for the O graphics program"
echo -e
echo -e "Updated on $last_update by Donald Raymond (Steve Harrison Lab)"
echo -e
echo -e "******************************************************************"


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

#get mtz file
get_file "$mtzfile" mtz && mtzfile="$loc_file"

echo -e "\nRunning sftools"
read_mtz

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
	exit 1
fi

#Ask user for map prefix
mapName=
while [[ $mapName = "" ]];do
	echo -n "Prefix for output map file: " 
	read mapName
done

##################################################
#
# make o files
#
##################################################

#make .O_files folder
O_dir=".O_files"

if [ -d "$O_dir" ]; then
	rm -rf "$O_dir/*" 2> /dev/null
else
	mkdir "$O_dir"
fi

#make o macro files
echo '! generates nearby symmetry atoms
symm_sph ;; 10.0' >> $O_dir/gen_symmetry

echo '.MENU                     T          48         40
colour_text red
STOP
colour_text white
<Save Database> Save_DB
colour_text magenta
<Clear flags> Clear_flags
colour_text green
Yes
colour_text red
No
colour_text cyan
<Centre ID> Centre_id
<Clear ID text> Clear_Id
colour_text yellow
<Build Residue> bu_res
<Build Rotamer> build_rot
colour_text cyan
<Baton Build> Baton_build
<Lego C alpha> Lego_CA
<Lego Loop> Lego_Loop
<Lego Side Chain> Lego_side_ch
<Add Water> Water_add
colour_text magenta
<RSR Group> Fm_rsr_grou
<RSR Rotamer> Fm_rsr_rota
<RSR Torsion> Fm_rsr_tors
<RSR Zone> Fm_rsr_zone
colour_text yellow
<Grab Atom> Grab_atom
<Grab Fragment> Grab_fragment
<Grab Residue> Grab_residue
<Move Zone> Move_zone
colour_text cyan
<Flip Peptide> Flip_peptide
<Refine Zone> Refi_zone
Tor_residue
colour_text yellow
<Distance> Dist_define
<Neighbours> Neighbour_atom
Trig_reset
Trig_refresh
colour_text turquoise
<Gen Symmetry> @.O_files/gen_symmetry
<Redraw Solv> @.O_files/redraw_solv
<Redraw Map> @.O_files/redraw_map
<Next Water> @.O_files/next_water
<Next ca> @.O_files/next_ca
<Previous ca> @.O_files/previous_ca' >> $O_dir/menu_raymond.odb

echo '! centers screen on next alpha-carbon and redraw
! electron density maps as defined in on_startup
centre_next atom_name = ca' >> $O_dir/next_ca

echo '! centers screen on next solvent molecule and
! redraws electron density maps as define in on_startup
centre_next atom_name = o' >> $O_dir/next_water

echo '! centers screen on next alpha-carbon and redraws
! electron density maps as defined in on_startup
centre_previous atom_name = ca' >> $O_dir/previous_ca

echo "! redraws maps defined in on_startup" > $O_dir/redraw_map

echo '! redraws solvent molecules and protein
! useful after using add_water command
! rename solv and hica as required
mol solv
zo ;end
mol hica' >> $O_dir/redraw_solv

echo '.ID_TEMPLATE         T          2         40
%Restyp %RESNAM %ATMNAM
residue_2ry_struc' >> $O_dir/resid.odb

#make on_startup file
echo -e "! read database files" > on_startup
echo -e "read .O_files/menu_raymond.odb" >> on_startup
echo -e "read old/residue_dict.odb" >> on_startup
echo -e "read .O_files/resid.odb\n" >> on_startup

echo -e "! open menus" >> on_startup
echo -e "win_open user_menu $m_user" >> on_startup
echo -e "win_open object_menu $m_object" >> on_startup
echo -e "win_open dial_menu $m_dial" >> on_startup
echo -e "win_open paint_display $m_paint\n" >> on_startup

echo -e "! display map in RMS units and not absolute" >> on_startup
echo -e "d_s_d .fm_real 2 2 1\n" >> on_startup

####################################################
#
#make ccp4 map
#
####################################################

echo -e "\nMaking and normalizing CCP4 map(s)"
case $map_coef in 
	F_DELWT) 	make_map $mtzfile $mapName-2FoFc.ccp4 $res_low $res_high FWT PHWT 
				make_map $mtzfile $mapName-FoFc.ccp4 $res_low $res_high DELFWT PHDELWT
				echo -e "\n\tCreated $mapName-2FoFc.ccp4 and $mapName-FoFc.ccp4"
				mapO $mapName-FoFc.ccp4  FoFc+ 3   green 1 "$den2"
				mapO $mapName-FoFc.ccp4  FoFc- -3   red 2 "$den3"
				mapO $mapName-2FoFc.ccp4 2FoFc 1.1 slate_blue 3 "$den1"
				redraw FoFc+
				redraw FoFc-
				redraw 2FoFc
					;;
	
	FDM)		make_map $mtzfile $mapName-DM.ccp4 $res_low $res_high FDM PHIDM
				echo -e "\n\tCreated $mapName-DM.ccp4"
				mapO $mapName-DM.ccp4 DM 1.1 slate_blue 1 "$den1"
				redraw DM
					;;

	FEM)		make_map $mtzfile $mapName-FEM.ccp4 $res_low $res_high FEM PHIFEM 
				echo -e "\n\tCreated $mapName-FEM.ccp4"
				mapO $mapName-FEM.ccp4 FEM 1.1 slate_blue 1 "$den1"
				redraw FEM
					;;
	
	FWT)		make_map $mtzfile $mapName.ccp4 $res_low $res_high FWT 
				echo -e "\n\tCreated $mapName.ccp4"
				mapO $mapName.ccp4 Den 1.1 slate_blue 1 "$den1"
				redraw Den
					;;
	
	2FO)		make_map $mtzfile $mapName-2FoFc.ccp4 $res_low $res_high 2FOFCWT PH2FOFCWT
				make_map $mtzfile $mapName-FoFc.ccp4 $res_low $res_high FOFCWT PHFOFCWT 
				echo -e "\n\tCreated $mapName-2FoFc.ccp4 and $mapName-FoFc.ccp4"
				mapO $mapName-FoFc.ccp4  FoFc+ 3   green 1 "$den2"
				mapO $mapName-FoFc.ccp4  FoFc- -3   red 2 "$den3"
				mapO $mapName-2FoFc.ccp4 2FoFc 1.1 slate_blue 3 "$den1" 
				redraw FoFc+
				redraw FoFc-
				redraw 2FoFc
					;;

	*)			echo -e "\nUnknow map coefficients labels"
				echo -e "Please send MTZ to raymond@crystal.harvard.edu to update script\n"
				exit 1
					;;
esac
 
#rm -rf sftoolsread.txt 2> /dev/null

#Ask user for pdb file
function askuser {
echo;echo -n "Would you like to Load a pdb file? (Y/N) "
while read -r -n 1 -s answer;do
  if [[ $answer = [YyNn] ]]; then
    [[ $answer = [Yy] ]] && retval=0
    [[ $answer = [Nn] ]] && retval=1
    break
  fi  
done
echo
return $retval
} 

if askuser; then
	#get pdb file
	get_file "$pdbfile" pdb && pdbfile="$loc_file"
		
	#Ask user for pdb name
	pdbName=""
	while [[ $pdbName = "" ]];do
		echo;echo -n "What is the PDB object's name? (6 or less characters): " 
		read -n 6 -e pdbName
	done

	echo -e "\n! Read pdb files" >> on_startup
	echo -e "pdb_read $pdbfile $pdbName ; ; ;" >> on_startup
	extra=" and PDB file"

else
	echo -e "\n\n\tNot loading a PDB file"
	extra=""
fi

#on_start file created
echo -e "\n\tAn on_startup file has been created for use in ONO."
echo -e "\n\tThe map(s)$extra will automatically be loaded into ONO upon launch."

#clean up
rm sftoolsread.txt

#Finish script
echo -e "\nScript finished\n"
