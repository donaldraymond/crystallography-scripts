#!/bin/bash

#for debugging
#set -x
##################################################################

#check if cif2mtz and refmac5 are installed
if hash curl 2>/dev/null && hash cif2mtz 2>/dev/null && hash refmac5 2>/dev/null && hash sftools 2>/dev/null && hash fft 2>/dev/null; then
	echo -e "\nFound curl, cif2mtz, refmac5, sftools and fft...continuing with script"
else
	echo -e "\ncurl, cif2mtz, refmac5, sftools and fft are required to run this script\n"
	exit 1
fi

#clear screen
clear

# Echo purpose of script
echo -e '
**********************************************************************

   This is a script for viewing results of Buster refinement in O

**********************************************************************
'

#list of variables
#variables to hold window positions
m_user="-1.66 0.56"
m_object="-1.66 0.94"
m_dial="1.44 -0.34"
m_paint="1.14 -0.34"

den1="1.06 0.98"
den2="1.06 0.65"
den3="1.06 0.32"

#############################
#Functions
#############################

#function to get resolution
function get_res {
grep "$1" $pdb_file | awk -F ":" '{print $2;exit}' | awk '{ gsub (" ", "", $0); print}'
}

#function to run sftools
function read_mtz {
#read file in sftools
sftools <<EOF > sftoolsread.txt
 read $mtzfile
 complete
 list
 quit
EOF
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

pdb_file="refine.pdb"
mtzfile="refine.mtz"

read_mtz

#get the resolution 
echo -e "Getting resolution limits"
res_low="`awk '/The resolution range in the data base is/ {print $9}' sftoolsread.txt`"
echo -e "\n\tLow resolution limit is $res_low"

res_high="`awk '/The resolution range in the data base is/ {print $11}' sftoolsread.txt`"
echo -e "\n\tHigh resolution limit is $res_high\n"

#get space group name
spaceGroupName="`awk '/Initializing CHKHKL for spacegroup/ {print $5}' sftoolsread.txt`"
echo -e "The space group is $spaceGroupName \n"

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

#make DSN6 map
echo -e "Making and normalizing DSN6 map(s)"
make_map $mtzfile 2FoFc.dn6 $res_low $res_high 2FOFCWT PH2FOFCWT 
make_map $mtzfile FoFc.dn6 $res_low $res_high FOFCWT PHFOFCWT
mapO FoFc.dn6  FoFc+ 3   green 1 "$den2"
mapO FoFc.dn6  FoFc- -3   red 2 "$den3"
mapO 2FoFc.dn6 2FoFc 1.1 slate_blue 3 "$den1"
redraw FoFc+
redraw FoFc-
redraw 2FoFc

echo -e "\n! Read pdb files" >> on_startup
echo -e "pdb_read $pdb_file obj ; ; ;" >> on_startup

#on_start file created
echo -e "\nAn on_startup file has been created for use in ONO.
\nThe PDB and maps will be loaded into O upon launch.
"

#clean up
rm sftoolsread.txt 2> /dev/null
