#!/bin/bash

#######################################################

# This is a script to create maps for ono
#written by Donald Raymond (raymond@crystal.harvard.edu)

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

#variables to hold window positions
m_user="-1.66 0.49"
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
 read $mtzfile
 complete
 list
 quit
 end
EOF
}

#function to get PDB object name
function obj_name {
	echo -e "\nI've found "$pdbfile" \n"
	read -e -p "What is the PDB object's name? [obj] " -n 6 pdbName
	while [[ -z "$pdbName" ]]; do
		pdbName=obj
	done

	echo -e "! Read pdb files" >> on_startup
	echo -e "pdb_read $pdbfile $pdbName ; ; ;" >> on_startup
	extra=" and PDB file"
}

#function to make map 1:input file 2:output file 3:low res 4:high res 5:F 6:phase
function make_map {
#make the map
#make temp.ccp4 file
tempCCP4=_temp$$.ccp4
fft HKLIN $1 MAPOUT $tempCCP4 << eof > /dev/null
xyzlim asu
resolution $3 $4
GRID SAMPLE 6.0
labin F1=$5 PHI=$6
end
eof

# normalize the map
mapmask mapin $tempCCP4  mapout $tempCCP4  << EOF > /dev/null
SCALE SIGMA
EOF

#convert to dn6 format
sftools << EOF > /dev/null
mapin $tempCCP4 map
mapout $2
quit
end
EOF

#delete temp files.
rm $tempCCP4
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

#function to add map to on_start
# $1-map file ; $2-map name; $3-sigma level; $4-color of electron density
# $5-density window number; $6-window position
function mapO {
	echo "fm_file $1 $2 $spaceGroupName" >> on_startup
	echo "Fm_setup $2 40 ; 1 $3 $4" >> on_startup
	echo "window_open density_$5 $6" >> on_startup
	echo >> on_startup
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
echo -e "This is a script to produce DSN6 maps for the O graphics program"
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
if [[ -z "$mtzfile" ]]; then
	echo -e "\nMTZs in current directory: `ls -m  *.mtz 2>/dev/null` \n"
	read -p "Load MTZ file: " mtzfile
	while [ ! -f "$mtzfile" ]; do
		echo
		read -p "I need a valid MTZ file: " mtzfile
	done
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
elif  $(grep -q PH2FOFCWT sftoolsread.txt) && ! $(grep -q PHFOFCWT sftoolsread.txt); then
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

#Ask user about map resolution
read -e -p "Resolution of map? [$reso_high] " res_high
while [[ -z "$res_high" ]]; do
	res_high=$reso_high
done

#Ask user for map prefix
echo
read -e -p "Prefix for output map file [map]: " mapName
while [[ -z $mapName ]]; do
	mapName="map"
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
symm_sph ;; 10.0' > $O_dir/gen_symmetry

echo '.MENU                     T          47         40
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
<Baton Build> Baton_build
<Add Water> Water_add
colour_text cyan
<Lego C alpha> Lego_CA
<Lego Loop> Lego_Loop
<Lego Side Chain> Lego_side_ch
<Lego auto SC> Lego_Auto_SC
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
<Fix atom> Refi_fix_atom
Tor_residue
colour_text yellow
<Distance> Dist_define
<Neighbours> Neighbour_atom
Trig_reset
Trig_refresh
colour_text turquoise
<Gen Symmetry> @.O_files/gen_symmetry
<Redraw Map> @.O_files/redraw_map
<Next Water> @.O_files/next_water
<Next ca> @.O_files/next_ca
<Previous ca> @.O_files/previous_ca' > $O_dir/menu_raymond.odb

echo '! centers screen on next alpha-carbon and redraw
! electron density maps as defined in on_startup
centre_next atom_name = ca' > $O_dir/next_ca

echo '! centers screen on next solvent molecule and
! redraws electron density maps as define in on_startup
centre_next atom_name = o' > $O_dir/next_water

echo '! centers screen on next alpha-carbon and redraws
! electron density maps as defined in on_startup
centre_previous atom_name = ca' > $O_dir/previous_ca

echo "! redraws maps defined in on_startup" > $O_dir/redraw_map

echo '.ID_TEMPLATE         T          2         40
%Restyp %RESNAM %ATMNAM
residue_2ry_struc' > $O_dir/resid.odb

echo '!
! colour CAs with bad pepflips
!
mol #Which molecule ?#
obj flip
sel_on ;;
pai_sel yellow
sel_off ;;
sel_prop residue_pepflip > #Cut off (A) ?# on
pai_sel red sel_on ;;
ca ; end' > $O_dir/bad_flip.omac

echo '!
! colour CAs with bad RS-fit values
!
mol #Which molecule ?#
obj rsfit
sel_on ;;
pai_sel yellow
sel_off ;;
sel_prop residue_rsfit < #Cut off ?# on
pai_sel red
sel_on ;;
ca ; end' > $O_dir/bad_rsfit.omac

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
#make DSN6 map
#
####################################################

echo -e "\nMaking and normalizing DSN6 map(s)"
case $map_coef in 
	F_DELWT) 	make_map $mtzfile $mapName-2FoFc.dn6 $res_low $res_high FWT PHWT 
				make_map $mtzfile $mapName-FoFc.dn6 $res_low $res_high DELFWT PHDELWT
				echo -e "\n\tCreated $mapName-2FoFc.dn6 and $mapName-FoFc.dn6"
				mapO $mapName-FoFc.dn6  FoFc+ 3   green 1 "$den2"
				mapO $mapName-FoFc.dn6  FoFc- -3   red 2 "$den3"
				mapO $mapName-2FoFc.dn6 2FoFc 1.1 slate_blue 3 "$den1"
				redraw FoFc+
				redraw FoFc-
				redraw 2FoFc
					;;
	
	FDM)		make_map $mtzfile $mapName-DM.dn6 $res_low $res_high FDM PHIDM
				echo -e "\n\tCreated $mapName-DM.dn6"
				mapO $mapName-DM.dn6 DM 1.1 slate_blue 1 "$den1"
				redraw DM
					;;

	FEM)		make_map $mtzfile $mapName-FEM.dn6 $res_low $res_high FEM PHIFEM 
				echo -e "\n\tCreated $mapName-FEM.dn6"
				mapO $mapName-FEM.dn6 FEM 1.1 slate_blue 1 "$den1"
				redraw FEM
					;;
	
	PARROT)		make_map $mtzfile $mapName-parrot.dn6 $res_low $res_high 'parrot.F_phi.F' 'parrot.F_phi.phi' 
				echo -e "\n\tCreated $mapName-parrot.ccp4"
				mapO $mapName-parrot.dn6 PARR 1.1 slate_blue 1 "$den1"
				redraw PARR
					;;
	
	FWT)		make_map $mtzfile $mapName.dn6 $res_low $res_high FWT PHWT 
				echo -e "\n\tCreated $mapName.dn6"
				mapO $mapName.dn6 Den 1.1 slate_blue 1 "$den1"
				redraw Den
					;;
	
	2FO)		make_map $mtzfile $mapName-2FoFc.dn6 $res_low $res_high 2FOFCWT PH2FOFCWT
				make_map $mtzfile $mapName-FoFc.dn6 $res_low $res_high FOFCWT PHFOFCWT 
				echo -e "\n\tCreated $mapName-2FoFc.dn6 and $mapName-FoFc.dn6"
				mapO $mapName-FoFc.dn6  FoFc+ 3   green 1 "$den2"
				mapO $mapName-FoFc.dn6  FoFc- -3   red 2 "$den3"
				mapO $mapName-2FoFc.dn6 2FoFc 1.1 slate_blue 3 "$den1" 
				redraw FoFc+
				redraw FoFc-
				redraw 2FoFc
					;;
	2FO_only)	make_map $mtzfile $mapName-2FoFc.dn6 $res_low $res_high 2FOFCWT PH2FOFCWT
				echo -e "\n\tCreated $mapName-2FoFc.dn6"
				mapO $mapName-2FoFc.dn6 2FoFc 1.1 slate_blue 1 "$den1" 
				redraw 2FoFc
					;;

	custom)		make_map $mtzfile $mapName.dn6 $res_low $res_high $amp $pha 
				echo -e "\n\tCreated $mapName.dn6"
				mapO $mapName.dn6 map 1.1 slate_blue 1 "$den1"
				redraw map
					;;
	
	*)			echo -e "\nUnknow map coefficients labels"
				echo -e "Please send MTZ to raymond@crystal.harvard.edu to update script\n"
				exit 1
					;;
esac
 
#Ask user for pdb file
if [[ -z "$pdbfile" ]]; then
	echo -e "\nPDBs in current directory: `ls -m  *.pdb 2>/dev/null` \n"
	read -e -p "Load PDB file [none] " pdbfile
	if [[ -z "$pdbfile" ]]; then
		extra=""
	else
		while [ ! -f "$pdbfile" ]; do
			echo
			read -e -p "I need a PDB file: " pdbfile
		done
		obj_name
	fi
else
	obj_name
fi

#on_start file created
echo -e "\n\tAn on_startup file has been created for use in ONO."
echo -e "\n\tThe map(s)$extra will automatically be loaded into ONO upon launch."

#clean up
rm sftoolsread.txt

#Finish script
echo -e "\nScript finished\n"
