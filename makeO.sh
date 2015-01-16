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

last_update="January 14 2015"

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

########
#  FUNCTIONS
########


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
#read file in sftools
#sftools <<EOF > sftoolsread.txt
sftools <<EOF | tee sftoolsread.txt
 read $mtzfile
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

####################################################
#
#Prepare ono file for launching O
#
####################################################

#function to append map name to o_files
function redraw {
echo "fm_draw $1" >> next_water
echo "fm_draw $1" >> next_ca
echo "fm_draw $1" >> previous_ca
echo "fm_draw $1" >> redraw_map
}

##################################################
#
# make o files
#
##################################################

#make o macro files
echo "! generates nearby symmetry atoms" > gen_symmetry
echo "symm_sph ;; 10.0" >> gen_symmetry
echo "" >> gen_symmetry

echo ".MENU                     T          48         40" > menu_raymond.odb
echo "colour_text red" >> menu_raymond.odb
echo "STOP" >> menu_raymond.odb
echo "colour_text white" >> menu_raymond.odb
echo "<Save Database> Save_DB" >> menu_raymond.odb
echo "colour_text magenta" >> menu_raymond.odb
echo "<Clear flags> Clear_flags" >> menu_raymond.odb
echo "colour_text green" >> menu_raymond.odb
echo "Yes" >> menu_raymond.odb
echo "colour_text red" >> menu_raymond.odb
echo "No" >> menu_raymond.odb
echo "colour_text cyan" >> menu_raymond.odb
echo "<Centre ID> Centre_id" >> menu_raymond.odb
echo "<Clear ID text> Clear_Id" >> menu_raymond.odb
echo "colour_text yellow" >> menu_raymond.odb
echo "<Build Residue> bu_res" >> menu_raymond.odb
echo "<Build Rotamer> build_rot" >> menu_raymond.odb
echo "colour_text cyan" >> menu_raymond.odb
echo "<Baton Build> Baton_build" >> menu_raymond.odb
echo "<Lego C alpha> Lego_CA" >> menu_raymond.odb
echo "<Lego Loop> Lego_Loop" >> menu_raymond.odb
echo "<Lego Side Chain> Lego_side_ch" >> menu_raymond.odb
echo "<Add Water> Water_add" >> menu_raymond.odb
echo "colour_text magenta" >> menu_raymond.odb
echo "<RSR Group> Fm_rsr_grou" >> menu_raymond.odb
echo "<RSR Rotamer> Fm_rsr_rota" >> menu_raymond.odb
echo "<RSR Torsion> Fm_rsr_tors" >> menu_raymond.odb
echo "<RSR Zone> Fm_rsr_zone" >> menu_raymond.odb
echo "colour_text yellow" >> menu_raymond.odb
echo "<Grab Atom> Grab_atom" >> menu_raymond.odb
echo "<Grab Fragment> Grab_fragment" >> menu_raymond.odb
echo "<Grab Residue> Grab_residue" >> menu_raymond.odb
echo "<Move Zone> Move_zone" >> menu_raymond.odb
echo "colour_text cyan" >> menu_raymond.odb
echo "<Flip Peptide> Flip_peptide" >> menu_raymond.odb
echo "<Refine Zone> Refi_zone" >> menu_raymond.odb
echo "Tor_residue" >> menu_raymond.odb
echo "colour_text yellow" >> menu_raymond.odb
echo "<Distance> Dist_define" >> menu_raymond.odb
echo "<Neighbours> Neighbour_atom" >> menu_raymond.odb
echo "Trig_reset" >> menu_raymond.odb
echo "Trig_refresh" >> menu_raymond.odb
echo "colour_text turquoise" >> menu_raymond.odb
echo "<gen symmetry> @gen_symmetry" >> menu_raymond.odb
echo "<redraw solv> @redraw_solv" >> menu_raymond.odb
echo "<redraw map> @redraw_map" >> menu_raymond.odb
echo "<next water> @next_water" >> menu_raymond.odb
echo "<next ca> @next_ca" >> menu_raymond.odb
echo "<previous ca> @previous_ca" >> menu_raymond.odb

echo "! centers screen on next alpha-carbon and redraws " > next_ca
echo "! electron density maps as defined in on_startup " >> next_ca
echo "centre_next atom_name = ca" >> next_ca

echo "! centers screen on next solvent molecule and" > next_water
echo "! redraws electron density maps as define in on_startup" >> next_water
echo "centre_next atom_name = o" >> next_water

echo "! centers screen on next alpha-carbon and redraws " > previous_ca
echo "! electron density maps as defined in on_startup " >> previous_ca
echo "centre_previous atom_name = ca" >> previous_ca

echo "! redraws maps defined in on_startup" > redraw_map

echo "! redraws solvent molecules and protein " > redraw_solv
echo "! useful after using add_water command " >> redraw_solv
echo "! rename solv and hica as required" >> redraw_solv
echo "mol solv" >> redraw_solv
echo "zo ;end" >> redraw_solv
echo "mol hica" >> redraw_solv

echo ".ID_TEMPLATE         T          2         40" > resid.odb
echo "%Restyp %RESNAM %ATMNAM" >> resid.odb
echo "residue_2ry_struc" >> resid.odb

#make Duke stereo chemistry files

echo '! stereochemistry database for O version 10, Date: 050919
! copied from Alwyn Jones`s stereo_chem.odb version 050802
! contains rotamers from Richardson Lab (Duke)
! reference: http://kinemage.biochem.duke.edu/ for naming and
! The "Penultimate Rotamer Library" from Lovell, Word, Richardson and  
! Richardson; Proteins 40:389-408, 2000
! corrected ASP Torsion PSI*

.bonds_angles t 2910 72
link connections between 2 lined atoms, must be < than this value
connect_all 2.0
connect_mc 2.0
connect_sc 4.8

residue GLC
centre C1
atom C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
fragment_all C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
fragment_mc C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
fragment_rsr_1  C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
torsion CHI1 C4 C5 C6 O6 O6
connect_all C1 C2 C3 C4 C5 O5 C1
connect_all C1 O1
connect_all C2 O2
connect_all C3 O3
connect_all C4 O4
connect_all C5 C6 O6
bond_distance C1 C2 1.53 0.02
bond_distance C2 C3 1.53 0.02
bond_distance C3 C4 1.53 0.02
bond_distance C4 C5 1.53 0.02
bond_distance C5 O5 1.43 0.02
bond_distance O5 C1 1.43 0.02
bond_distance C1 O1 1.40 0.02
bond_distance C2 O2 1.40 0.02
bond_distance C3 O3 1.40 0.02
bond_distance C4 O4 1.40 0.02
bond_distance C5 C6 1.51 0.02
bond_distance C6 O6 1.40 0.02
bond_angle C1 C2 C3 109.0 2.0
bond_angle C2 C3 C4 109.0 2.0
bond_angle C3 C4 C5 109.0 2.0
bond_angle C4 C5 O5 109.0 2.0
bond_angle C5 O5 C1 109.0 2.0
bond_angle O1 C1 C2 109.0 2.0
bond_angle O1 C1 O5 109.0 2.0
bond_angle O2 C2 C3 109.0 2.0
bond_angle O2 C2 C1 109.0 2.0
bond_angle O3 C3 C4 109.0 2.0
bond_angle O3 C3 C2 109.0 2.0
bond_angle O4 C4 C5 109.0 2.0
bond_angle O4 C4 C3 109.0 2.0
bond_angle C6 C5 O5 109.0 2.0
bond_angle C6 C5 C4 109.0 2.0
bond_angle O6 C6 C5 109.0 2.0
torsion_fixed C2 C1 O1 O5 -120.0 2.0
torsion_fixed C3 C2 O2 C1 +120.0 2.0
torsion_fixed C4 C3 O3 C2 -120.0 2.0
torsion_fixed C5 C4 O4 C3 +120.0 2.0
torsion_fixed O5 C5 C6 C4 -120.0 2.0
torsion_flexible O6 C6 C5 C4 180.0 20.0
! now come the ring pucker torsion angles
torsion_fixed C1 C2 C3 C4 -56.0 2.0 
torsion_fixed C2 C3 C4 C5 +57.0 2.0
torsion_fixed C3 C4 C5 O5 -60.0 2.0
torsion_fixed C4 C5 O5 C1 +64.0 2.0
torsion_fixed C5 O5 C1 C2 -64.0 2.0
torsion_fixed O5 C1 C2 C3 +58.0 2.0
------------------------------------------------------------------------
residue GAL
centre C1
atom C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
fragment_all C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
fragment_mc C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
fragment_rsr_1 C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 C6 O6
torsion CHI1 C4 C5 C6 O6 O6
connect_all C1 C2 C3 C4 C5 O5 C1
connect_all C1 O1
connect_all C2 O2
connect_all C3 O3
connect_all C4 O4
connect_all C5 C6 O6
bond_distance C1 C2 1.53 0.02
bond_distance C2 C3 1.53 0.02
bond_distance C3 C4 1.53 0.02
bond_distance C4 C5 1.53 0.02
bond_distance C5 O5 1.43 0.02
bond_distance O5 C1 1.43 0.02
bond_distance C1 O1 1.40 0.02
bond_distance C2 O2 1.40 0.02
bond_distance C3 O3 1.40 0.02
bond_distance C4 O4 1.40 0.02
bond_distance C5 C6 1.51 0.02
bond_distance C6 O6 1.40 0.02
bond_angle C1 C2 C3 109.0 2.0
bond_angle C2 C3 C4 109.0 2.0
bond_angle C3 C4 C5 109.0 2.0
bond_angle C4 C5 O5 109.0 2.0
bond_angle C5 O5 C1 109.0 2.0
bond_angle O1 C1 C2 109.0 2.0
bond_angle O1 C1 O5 109.0 2.0
bond_angle O2 C2 C3 109.0 2.0
bond_angle O2 C2 C1 109.0 2.0
bond_angle O3 C3 C4 109.0 2.0
bond_angle O3 C3 C2 109.0 2.0
bond_angle O4 C4 C5 109.0 2.0
bond_angle O4 C4 C3 109.0 2.0
bond_angle C6 C5 O5 109.0 2.0
bond_angle C6 C5 C4 109.0 2.0
bond_angle O6 C6 C5 109.0 2.0
torsion_fixed C2 C1 O1 O5 -120.0 2.0
torsion_fixed C3 C2 O2 C1 +120.0 2.0
torsion_fixed C4 C3 O3 C2 -120.0 2.0
torsion_fixed C5 C4 O4 C3 -120.0 2.0
torsion_fixed O5 C5 C6 C4 -120.0 2.0
torsion_flexible O6 C6 C5 C4 180.0 20.0
! now come the ring pucker torsion angles
torsion_fixed C1 C2 C3 C4 -56.0 2.0 
torsion_fixed C2 C3 C4 C5 +57.0 2.0
torsion_fixed C3 C4 C5 O5 -60.0 2.0
torsion_fixed C4 C5 O5 C1 +64.0 2.0
torsion_fixed C5 O5 C1 C2 -64.0 2.0
torsion_fixed O5 C1 C2 C3 +58.0 2.0
------------------------------------------------------------------------
residue XYL
centre C1
atom C1 C2 C3 C4 C5 O5 O1 O2 O3 O4
fragment_all C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 
fragment_mc C1 C2 C3 C4 C5 O5 O1 O2 O3 O4 
fragment_rsr_1 C1 C2 C3 C4 C5 O5 O1 O2 O3 O4
connect_all C1 C2 C3 C4 C5 O5 C1
connect_all C1 O1
connect_all C2 O2
connect_all C3 O3
connect_all C4 O4
bond_distance C1 C2 1.53 0.02
bond_distance C2 C3 1.53 0.02
bond_distance C3 C4 1.53 0.02
bond_distance C4 C5 1.53 0.02
bond_distance C5 O5 1.43 0.02
bond_distance O5 C1 1.43 0.02
bond_distance C1 O1 1.40 0.02
bond_distance C2 O2 1.40 0.02
bond_distance C3 O3 1.40 0.02
bond_distance C4 O4 1.40 0.02
bond_angle C1 C2 C3 109.0 2.0
bond_angle C2 C3 C4 109.0 2.0
bond_angle C3 C4 C5 109.0 2.0
bond_angle C4 C5 O5 109.0 2.0
bond_angle C5 O5 C1 109.0 2.0
bond_angle O1 C1 C2 109.0 2.0
bond_angle O1 C1 O5 109.0 2.0
bond_angle O2 C2 C3 109.0 2.0
bond_angle O2 C2 C1 109.0 2.0
bond_angle O3 C3 C4 109.0 2.0
bond_angle O3 C3 C2 109.0 2.0
bond_angle O4 C4 C5 109.0 2.0
bond_angle O4 C4 C3 109.0 2.0
torsion_fixed C2 C1 O1 O5 -120.0 2.0
torsion_fixed C3 C2 O2 C1 +120.0 2.0
torsion_fixed C4 C3 O3 C2 -120.0 2.0
torsion_fixed C5 C4 O4 C3 +120.0 2.0
! now come the ring pucker torsion angles
torsion_fixed C1 C2 C3 C4 -56.0 2.0 
torsion_fixed C2 C3 C4 C5 +57.0 2.0
torsion_fixed C3 C4 C5 O5 -60.0 2.0
torsion_fixed C4 C5 O5 C1 +64.0 2.0
torsion_fixed C5 O5 C1 C2 -64.0 2.0
torsion_fixed O5 C1 C2 C3 +58.0 2.0
------------------------------------------------------------------------
residue PEP
centre CA
main-chain CA C O N* CA*
------------------------------------------------------------------------
residue ALA 
centre CA
ATOM   N     CA    C     O     CB
fragment_all N     CA    C     O     CB
fragment_mc N     CA    C     O     CB
fragment_sc CB
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
main-chain N CA C O CB
side-chain CB
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
torsion PHI  C- N CA C CB C O
torsion PSI*  N CA C O O
connect_sc -  CA    +
connect_sc CA    CB
connect_all -     N     CA    C     +
connect_all CA    CB
connect_all C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.521 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.400 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue ARG 
centre CA
ATOM   N     CA    C     O     CB    CG    CD    NE  CZ  NH1 NH2
fragment_all N     CA    C     O     CB    CG    CD    NE  CZ  NH1 NH2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG CD NE   CZ   NH1 NH2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3 CB CG CD
fragment_rsr_4 CG CD NE
fragment_rsr_5 CD NE  CZ   NH1 NH2
side-chain CB CG CD NE   CZ   NH1 NH2
main-chain N CA C O CB
phi   C-   N    CA   C
psi   N    CA   C    N+
omega CA   C    N+   CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
chi1  N    CA   CB   CG
chi2  CA   CB   CG   CD
chi3  CB   CG   CD   NE
chi4  CG   CD   NE   CZ
chi5  CD   NE   CZ   NH1
rotamer mmmm_2  chi1  -62. chi2  -68. chi3  -65. chi4  -85. chi5  0.
rotamer mmmt_1  chi1  -62. chi2  -68. chi3  -65. chi4  175. chi5  0.
rotamer mmtm_2  chi1  -62. chi2  -68. chi3  180. chi4  -85. chi5  0.
rotamer mmtt_2  chi1  -62. chi2  -68. chi3  180. chi4  180. chi5  0.
rotamer mmtp_1  chi1  -62. chi2  -68. chi3  180. chi4   85. chi5  0.
rotamer mtmm_6  chi1  -67. chi2 -167. chi3  -65. chi4  -85. chi5  0.
rotamer mtmt_5  chi1  -67. chi2  180. chi3  -65. chi4  175. chi5  0.
rotamer mtmp_2  chi1  -67. chi2  180. chi3  -65. chi4  105. chi5  0.
rotamer mttm_6  chi1  -67. chi2  180. chi3  180. chi4  -85. chi5  0.
rotamer mttt_9  chi1  -67. chi2  180. chi3  180. chi4  180. chi5  0.
rotamer mttp_4  chi1  -67. chi2  180. chi3  180. chi4   85. chi5  0.
rotamer mtpm_1  chi1  -67. chi2  180. chi3   65. chi4 -105. chi5  0.
rotamer mtpt_5  chi1  -67. chi2  180. chi3   65. chi4 -175. chi5  0.
rotamer mtpp_2  chi1  -67. chi2  180. chi3   65. chi4   85. chi5  0.
rotamer ttmm_3  chi1 -177. chi2  180. chi3  -65. chi4  -85. chi5  0.
rotamer ttmt_1  chi1 -177. chi2  180. chi3  -65. chi4  175. chi5  0.
rotamer ttmp_1  chi1 -177. chi2  180. chi3  -65. chi4  105. chi5  0.
rotamer tttm_3  chi1 -177. chi2  180. chi3  180. chi4  -85. chi5  0.
rotamer tttt_4  chi1 -177. chi2  180. chi3  180. chi4  180. chi5  0.
rotamer tttp_2  chi1 -177. chi2  180. chi3  180. chi4   85. chi5  0.
rotamer ttpm_1  chi1 -177. chi2  180. chi3   65. chi4 -105. chi5  0.
rotamer ttpt_3  chi1 -177. chi2  180. chi3   65. chi4 -175. chi5  0.
rotamer ttpp_4  chi1 -177. chi2  180. chi3   65. chi4   85. chi5  0.
rotamer tptt_2  chi1 -177. chi2   65. chi3  180. chi4  180. chi5  0.
rotamer tptp_2  chi1 -177. chi2   65. chi3  180. chi4   85. chi5  0.
rotamer tppt_1  chi1 -177. chi2   65. chi3   65. chi4 -175. chi5  0.
rotamer tppp_1  chi1 -177. chi2   65. chi3   65. chi4   85. chi5  0.
rotamer ptmm_1  chi1   62. chi2  180. chi3  -65. chi4  -85. chi5  0.
rotamer ptmt_1  chi1   62. chi2  180. chi3  -65. chi4  175. chi5  0.
rotamer pttm_2  chi1   62. chi2  180. chi3  180. chi4  -85. chi5  0.
rotamer pttt_2  chi1   62. chi2  180. chi3  180. chi4  180. chi5  0.
rotamer pttp_2  chi1   62. chi2  180. chi3  180. chi4   85. chi5  0.
rotamer ptpt_1  chi1   62. chi2  180. chi3   65. chi4 -175. chi5  0.
rotamer ptpp<1  chi1   62. chi2  180. chi3   65. chi4   85. chi5  0.
torsion PHI  C- N CA C CB C O CG CD NE CZ NH1 NH2
torsion PSI*  N CA C O O
torsion CHI1 N CA CB CG CG CD NE CZ NH1 NH2
torsion CHI2 CA CB CG CD CD NE CZ NH1 NH2
torsion CHI3 CB CG CD NE NE CZ NH1 NH2
torsion CHI4 CG CD NE CZ CZ NH1 NH2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD    NE    CZ    NH1
CONNECT_sc CZ    NH2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD    NE    CZ    NH1
CONNECT_ALL CZ    NH2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.520 0.02
bond_distance CD   CG      1.520 0.02
bond_distance NE   CD      1.460 0.02
bond_distance CZ   NE      1.329 0.02
bond_distance NH2  CZ      1.326 0.02
bond_distance NH1  CZ      1.326 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    114.100 2.0
bond_angle CD   CG   CB    111.300 2.0
bond_angle NE   CD   CG    112.000 2.0
bond_angle CZ   NE   CD    124.200 2.0
bond_angle NH2  CZ   NE    120.000 2.0
bond_angle NH1  CZ   NE    120.000 2.0
bond_angle NH1  CZ   NH2   120.000 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     180.000 20.
torsion_flexible CD   CG   CB   CA    180.000 20.
torsion_flexible NE   CD   CG   CB    180.000 20.
torsion_flexible CZ   NE   CD   CG    180.000 20.
torsion_fixed    NE   CZ   NH1  NH2   180.000 2.0
torsion_fixed    NH1  CZ   NE   CD      0.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue ASN 
centre CA
ATOM   N     CA    C     O     CB    CG    OD1   ND2
fragment_all  N     CA    C     O     CB    CG    OD1   ND2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG OD1 ND2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG OD1 ND2
side-chain CB CG OD1 ND2
main-chain N CA C O CB
chi1 N CA CB CG
chi2 CA CB CG OD1
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m-80_8  chi1  -65. chi2  -75.
rotamer m-20**  chi1  -65. chi2  -20.
rotamer m120_4  chi1  -65. chi2  120.
rotamer St-80_  chi1 -174. chi2  -80.
rotamer t-20**  chi1 -174. chi2  -20.
rotamer t30_15  chi1 -177. chi2   30.
rotamer Sp-50_  chi1   62. chi2  -50.
rotamer p-10_7  chi1   62. chi2  -10.
rotamer p30__9  chi1   62. chi2   30.
torsion PHI  C- N CA C CB C O CG OD1 ND2
torsion PSI* N CA C O O
torsion CHI1 N CA CB CG CG OD1 ND2
torsion CHI2 CA CB CG OD1 OD1 ND2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    OD1
CONNECT_sc CG    ND2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    OD1
CONNECT_ALL CG    ND2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.516 0.02
bond_distance OD1  CG      1.231 0.02
bond_distance ND2  CG      1.328 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    112.600 2.0
bond_angle OD1  CG   CB    120.800 2.0
bond_angle ND2  CG   CB    116.400 2.0
bond_angle ND2  CG   OD1   122.800 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_fixed    CB   CG   OD1  ND2   180.000 2.0
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible OD1  CG   CB   CA    -40.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue ASP 
centre CA
ATOM   N     CA    C     O     CB    CG    OD1   OD2
fragment_all N     CA    C     O     CB    CG    OD1   OD2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG OD1 OD2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG OD1 OD2
side-chain CB CG OD1 OD2
main-chain N CA C O CB
chi1 N CA CB CG
chi2 CA CB CG OD1
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m-20**  chi1  -70. chi2  -15.
rotamer Sm-60_  chi1  -65. chi2  -60.
rotamer St-30_  chi1 -170. chi2  -30.
rotamer t0__21  chi1 -177. chi2    0.
rotamer t70__6  chi1 -177. chi2   65.
rotamer Sp-50_  chi1   62. chi2  -50.
rotamer p-10**  chi1   62. chi2  -10.
rotamer p30__9  chi1   62. chi2   30.
torsion PHI C- N CA C CB C O CG OD1 OD2
torsion PSI* N CA C O O
torsion CHI1 N CA CB CG CG OD1 OD2
torsion CHI2 CA CB CG OD1 OD1 OD2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    OD1
CONNECT_sc CG    OD2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    OD1
CONNECT_ALL CG    OD2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.516 0.02
bond_distance OD1  CG      1.249 0.02
bond_distance OD2  CG      1.249 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    112.600 2.0
bond_angle OD1  CG   CB    118.400 2.0
bond_angle OD2  CG   CB    118.400 2.0
bond_angle OD2  CG   OD1   123.200 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -600.000 20.
torsion_fixed    CB   CG   OD1  OD2   180.000 2.0
torsion_flexible OD1  CG   CB   CA    -20.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue CYH 
centre CA
ATOM   N     CA    C     O    CB    SG
fragment_all  N     CA    C     O    CB    SG
fragment_mc N     CA    C     O     CB
fragment_sc CB SG
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB SG
side-chain CB SG
main-chain N CA C O CB
chi1 N CA CB SG
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m___50  chi1  -65.
rotamer t___26  chi1 -177.
rotamer p___23  chi1   62.
TORSION PHI C- N CA C CB C O SG
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB SG SG
connect_sc -  CA    +
CONNECT_sc CA    CB    SG
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    SG
CONNECT_ALL C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance SG   CB      1.808 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle SG   CB   CA    114.400 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsion
torsion_flexible SG   CB   CA   N     -60.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue CYS 
centre CA
ATOM   N     CA    C     O    CB    SG
fragment_all N     CA    C     O    CB    SG
fragment_mc N     CA    C     O     CB
fragment_sc CB SG
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB SG
side-chain CB SG
main-chain N CA C O CB
chi1 N CA CB SG
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m___50  chi1  -65.
rotamer t___26  chi1 -177.
rotamer p___23  chi1   62.
TORSION PHI C- N CA C CB C O SG
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB SG SG
connect_sc -  CA    +
CONNECT_sc CA    CB    SG
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    SG
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance SG   CB      1.822 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle SG   CB   CA    114.400 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsion
torsion_flexible SG   CB   CA   N     -65.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue GLN 
centre CA
ATOM   N     CA    C     O     CB    CG    CD    OE1   NE2
fragment_all  N     CA    C     O     CB    CG    CD    OE1   NE2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG CD OE1 NE2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG CD
fragment_rsr_4 CG CD OE1 NE2
side-chain CB CG CD OE1 NE2
main-chain N CA C O CB
chi1  N   CA  CB  CG
chi2  CA  CB  CG  CD
chi3  CB  CG  CD  OE1
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer mm-40*  chi1  -65. chi2  -65. chi3  -40.
rotamer mm100*  chi1  -65. chi2  -65. chi3  100.
rotamer Smt-60  chi1  -67. chi2  180. chi3  -60.
rotamer mt-30*  chi1  -67. chi2  180. chi3  -25.
rotamer Smt60_  chi1  -67. chi2  180. chi3   60.
rotamer mp0__3  chi1  -65. chi2   85. chi3    0.
rotamer Stt-60  chi1 -177. chi2  180. chi3  -60.
rotamer tt0_16  chi1 -177. chi2  180. chi3    0.
rotamer Stt60_  chi1 -177. chi2  180. chi3   60.
rotamer tp-100  chi1 -177. chi2   65. chi3 -100.
rotamer tp60_9  chi1 -177. chi2   65. chi3   60.
rotamer pm0__2  chi1   70. chi2  -75. chi3    0.
rotamer Spt-60  chi1   62. chi2  180. chi3  -60.
rotamer pt20_4  chi1   62. chi2  180. chi3   20.
rotamer Spt60_  chi1   62. chi2  180. chi3   60.
TORSION PHI C- N CA C CB C O CG CD OE1 NE2
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG CD OE1 NE2
TORSION CHI2 CA CB CG CD CD OE1 NE2
TORSION CHI3 CB CG CD OE1 OE1 NE2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD    OE1
CONNECT_sc CD    NE2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD    OE1
CONNECT_ALL CD    NE2
CONNECT_ALL C     O 
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.520 0.02
bond_distance CD   CG      1.516 0.02
bond_distance OE1  CD      1.231 0.02
bond_distance NE2  CD      1.328 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    114.100 2.0
bond_angle CD   CG   CB    112.600 2.0
bond_angle OE1  CD   CG    120.800 2.0
bond_angle NE2  CD   CG    126.400 2.0
bond_angle NE2  CD   OE1   112.800 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible CD   CG   CB   CA    180.000 20.
torsion_flexible OE1  CD   CG   CB      0.000 20.
torsion_fixed    CG   CD   OE1  NE2   180.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue GLU 
centre CA
ATOM   N     CA    C     O     CB    CG    CD    OE1   OE2
fragment_all N     CA    C     O     CB    CG    CD    OE1   OE2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG CD OE1 OE2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG CD
fragment_rsr_4 CG CD OE1 OE2
side-chain CB CG CD OE1 OE2
main-chain N CA C O CB
chi1  N   CA  CB  CG
chi2  CA  CB  CG  CD
chi3  CB  CG  CD  OE1
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer mm-40*  chi1  -65. chi2  -65. chi3  -40.
rotamer Smm0__  chi1  -65. chi2  -75. chi3    0.
rotamer Smt-60  chi1  -67. chi2  180. chi3  -60.
rotamer mt-10*  chi1  -67. chi2  180. chi3  -10.
rotamer Smt60_  chi1  -67. chi2  180. chi3   60.
rotamer mp0__6  chi1  -65. chi2   85. chi3    0.
rotamer tm-20*  chi1 -177. chi2  -80. chi3  -25.
rotamer Stt-60  chi1 -177. chi2  180. chi3  -60.
rotamer tt0_24  chi1 -177. chi2  180. chi3    0.
rotamer Stt60_  chi1 -177. chi2  180. chi3   60.
rotamer tp10_6  chi1 -177. chi2   65. chi3   10.
rotamer pm0__2  chi1   70. chi2  -80. chi3    0.
rotamer Spt-60  chi1   62. chi2  180. chi3  -60.
rotamer pt-20*  chi1   62. chi2  180. chi3  -20.
rotamer Spt60_  chi1   62. chi2  180. chi3   60.
TORSION PHI C- N CA C CB C O CG CD OE1 OE2
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG CD OE1 OE2
TORSION CHI2 CA CB CG CD CD OE1 OE2
TORSION CHI3 CB CG CD OE1 OE1 OE2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD    OE1   
CONNECT_sc CD    OE2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD    OE1   
CONNECT_ALL CD    OE2
CONNECT_ALL C     O 
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.520 0.02
bond_distance CD   CG      1.516 0.02
bond_distance OE1  CD      1.249 0.02
bond_distance OE2  CD      1.249 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    114.100 2.0
bond_angle CD   CG   CB    112.600 2.0
bond_angle OE1  CD   CG    118.400 2.0
bond_angle OE2  CD   CG    118.400 2.0
bond_angle OE2  CD   OE1   123.200 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible CD   CG   CB   CA    180.000 20.
torsion_flexible OE1  CD   CG   CB      0.000 20.
torsion_fixed    CG   CD   OE1  OE2   180.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue GLY 
centre CA
ATOM   N     CA    C     O
fragment_all  N     CA    C     O
fragment_mc N     CA    C     O     CB
fragment_sc CA
fragment_rsr_1 CA C O N+ CA+
main-chain N CA C O
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
conformer aleft phi 50. psi 38.
TORSION PHI C- N CA C C O O
TORSION PSI* N CA C O O
connect_sc -  CA    +
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.451 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    N+    123.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue HIS 
centre CA
ATOM   N     CA    C     O     CB    CG    ND1   CD2   CE1   NE2
fragment_all  N     CA    C     O     CB    CG    ND1   CD2   CE1   NE2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG CD2 ND1 CE1 NE2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3 CB CG CD2 ND1 CE1 NE2
side-chain CB CG CD2 ND1 CE1 NE2
main-chain N CA C O CB
chi1  N   CA  CB  CG
chi2  CA  CB  CG  ND1
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m-70**  chi1  -65. chi2  -70.
rotamer m170_7  chi1  -65. chi2  165.
rotamer m80_13  chi1  -65. chi2   80.
rotamer t-80**  chi1 -177. chi2  -80.
rotamer t-160*  chi1 -177. chi2 -165.
rotamer t60_16  chi1 -177. chi2   60.
rotamer p-80_9  chi1   62. chi2  -75.
rotamer p80__4  chi1   62. chi2   80.
TORSION PHI C- N CA C CB CG ND1 CD2 CE1 NE2 C O
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG ND1 CD2 CE1 NE2
TORSION CHI2 CA CB CG ND1 ND1 CD2 CE1 NE2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    ND1   CE1   NE2
CONNECT_sc CG    CD2   NE2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    ND1   CE1   NE2
CONNECT_ALL CG    CD2   NE2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.549 0.02
bond_distance CD2  CG      1.354 0.02
bond_distance ND1  CG      1.378 0.02
bond_distance CE1  ND1     1.321 0.02
bond_distance NE2  CE1     1.321 0.02
bond_distance CD2  NE2     1.374 0.02
bond_distance CG   CD2     1.354 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    113.800 2.0
bond_angle CD2  CG   CB    131.200 2.0
bond_angle ND1  CG   CB    122.700 2.0
bond_angle ND1  CG   CD2   106.100 2.0
bond_angle CE1  ND1  CG    109.300 2.0
bond_angle NE2  CE1  ND1   108.400 2.0
bond_angle CD2  NE2  CE1   109.000 2.0
bond_angle CG   CD2  NE2   107.200 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible ND1  CG   CB   CA    -70.000 20.
torsion_fixed    CB   CG   ND1  CD2   180.000 2.0
torsion_fixed    CE1  ND1  CG   CB    180.000 2.0
torsion_fixed    NE2  CE1  ND1  CG      0.000 2.0
torsion_fixed    CD2  NE2  CE1  ND1     0.000 2.0
torsion_fixed    CG   CD2  NE2  CE1     0.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue ILE 
centre CA
ATOM   N     CA    C     O     CB    CG1   CG2   CD1
fragment_all N     CA    C     O     CB    CG1   CG2   CD1
fragment_mc N     CA    C     O     CB
fragment_sc CB CG1 CD1 CG2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG1 CG2
fragment_rsr_4  CB CG1 CD1
side-chain CB CG1 CD1 CG2
main-chain N CA C O CB
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
chi1  N   CA  CB  CG1
chi2  CA  CB  CG1 CD1
rotamer mm__15  chi1  -57. chi2  -60.
rotamer mt__60  chi1  -65. chi2  170.
rotamer mp___1  chi1  -65. chi2  100.
rotamer tt___8  chi1 -177. chi2  165.
rotamer tp___2  chi1 -177. chi2   66.
rotamer pt__13  chi1   62. chi2  170.
rotamer pp___1  chi1   62. chi2  100.
TORSION PHI C- N CA C CB CG1 CD1 CG2 C O
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG1 CG1 CD1 CG2
TORSION CHI2 CA CB CG1 CD1 CD1
connect_sc -  CA    +
CONNECT_sc CA    CB    CG1   CD1
CONNECT_sc CB    CG2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG1   CD1
CONNECT_ALL CB    CG2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.540 0.02
bond_distance CG2  CB      1.521 0.02
bond_distance CG1  CB      1.530 0.02
bond_distance CD1  CG1     1.513 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     111.500 2.0
bond_angle CG2  CB   CA    110.500 2.0
bond_angle CG1  CB   CA    110.400 2.0
bond_angle CG1  CB   CG2   110.400 2.0
bond_angle CD1  CG1  CB    113.800 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_fixed    CA   CB   CG1  CG2  -123.000 2.0
torsion_flexible CG1  CB   CA   N     -60.000 20.
torsion_flexible CD1  CG1  CB   CA    170.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue LEU 
centre CA
ATOM   N     CA    C     O     CB    CG    CD1   CD2
fragment_all N     CA    C     O     CB    CG    CD1   CD2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG CD1 CD2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG CD1 CD2
side-chain CB CG CD1 CD2
main-chain N CA C O CB
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
chi1  N   CA  CB  CG
chi2  CA  CB  CG  CD1
rotamer mt__59  chi1  -65. chi2  175.
rotamer mp___2  chi1  -85. chi2   65.
rotamer tt___2  chi1 -172. chi2  145.
rotamer tp__29  chi1 -177. chi2   65.
rotamer pp___1  chi1   62. chi2   80.
TORSION PHI C- N CA C CB CG CD1 CD2 C O
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG CD1 CD2
TORSION CHI2 CA CB CG CD1 CD1 CD2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD1
CONNECT_sc CG    CD2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD1
CONNECT_ALL CG    CD2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.530 0.02
bond_distance CD1  CG      1.521 0.02
bond_distance CD2  CG      1.521 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    116.300 2.0
bond_angle CD1  CG   CB    110.700 2.0
bond_angle CD2  CG   CB    110.700 2.0
bond_angle CD2  CG   CD1   110.700 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     180.000 20.
torsion_flexible CD1  CG   CB   CA    180.000 20.
torsion_fixed    CB   CG   CD1  CD2   123.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue LYS 
centre CA
ATOM   N     CA    C     O     CB    CG    CD    CE    NZ
fragment_all N     CA    C     O     CB    CG    CD    CE    NZ
fragment_mc N     CA    C     O     CB
fragment_sc CB CG  CD  CE  NZ
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3 CB CG CD
fragment_rsr_4 CD CE  NZ
!fragment_rsr_3 CA CB CG
!fragment_rsr_4 CB CG CD
!fragment_rsr_5 CG CD  CE
!fragment_rsr_6 CD  CE  NZ
side-chain CB CG  CD  CE  NZ
main-chain N CA C O CB
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
chi1  N   CA  CB  CG
chi2  CA  CB  CG  CD
chi3  CB  CG  CD  CE
chi4  CG  CD  CE  NZ
rotamer mmmt_1  chi1  -62. chi2  -68. chi3  -68. chi4  180.
rotamer mmtm_1  chi1  -62. chi2  -68. chi3  180. chi4  -65.
rotamer mmtt_6  chi1  -62. chi2  -68. chi3  180. chi4  180.
rotamer mmtp_1  chi1  -62. chi2  -68. chi3  180. chi4   65.
rotamer mtmm_1  chi1  -67. chi2  180. chi3  -68. chi4  -65.
rotamer mtmt_3  chi1  -67. chi2  180. chi3  -68. chi4  180.
rotamer mttm_5  chi1  -67. chi2  180. chi3  180. chi4  -65.
rotamer mttt20  chi1  -67. chi2  180. chi3  180. chi4  180.
rotamer mttp_3  chi1  -67. chi2  180. chi3  180. chi4   65.
rotamer mtpt_3  chi1  -67. chi2  180. chi3   68. chi4  180.
rotamer mtpp_1  chi1  -67. chi2  180. chi3   68. chi4   65.
rotamer mptt<1  chi1  -90. chi2   68. chi3  180. chi4  180.
rotamer ttmm<1  chi1 -177. chi2  180. chi3  -68. chi4  -65.
rotamer ttmt_2  chi1 -177. chi2  180. chi3  -68. chi4  180.
rotamer tttm_3  chi1 -177. chi2  180. chi3  180. chi4  -65.
rotamer tttt13  chi1 -177. chi2  180. chi3  180. chi4  180.
rotamer tttp_4  chi1 -177. chi2  180. chi3  180. chi4   65.
rotamer ttpt_2  chi1 -177. chi2  180. chi3   68. chi4  180.
rotamer ttpp_1  chi1 -177. chi2  180. chi3   68. chi4   65.
rotamer tptm_1  chi1 -177. chi2   68. chi3  180. chi4  -65.
rotamer tptt_3  chi1 -177. chi2   68. chi3  180. chi4  180.
rotamer tptp_1  chi1 -177. chi2   68. chi3  180. chi4   65.
rotamer ptmt<1  chi1   62. chi2  180. chi3  -68. chi4  180.
rotamer pttm_1  chi1   62. chi2  180. chi3  180. chi4  -65.
rotamer pttt_2  chi1   62. chi2  180. chi3  180. chi4  180.
rotamer pttp_1  chi1   62. chi2  180. chi3  180. chi4   65.
rotamer ptpt_1  chi1   62. chi2  180. chi3   68. chi4  180.
TORSION PHI C- N CA C CB C O CG CD CE NZ
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG CD CE NZ
TORSION CHI2 CA CB CG CD CD CE NZ
TORSION CHI3 CB CG CD CE CE NZ
TORSION CHI4 CG CD CE NZ NZ
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD    CE    NZ
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD    CE    NZ
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.520 0.02
bond_distance CD   CG      1.520 0.02
bond_distance CE   CD      1.520 0.02
bond_distance NZ   CE      1.489 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    114.100 2.0
bond_angle CD   CG   CB    111.300 2.0
bond_angle CE   CD   CG    111.300 2.0
bond_angle NZ   CE   CD    111.900 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible CD   CG   CB   CA   -170.000 20.
torsion_flexible CE   CD   CG   CB    180.000 20.
torsion_flexible NZ   CE   CD   CG    180.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue MET 
centre CA
ATOM   N     CA    C     O     CB    CG    SD    CE
fragment_all N     CA    C     O     CB    CG    SD    CE
fragment_mc N     CA    C     O     CB
fragment_sc CB CG  SD  CE
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG SD
fragment_rsr_4 CG  SD  CE
side-chain CB CG  SD  CE
main-chain N CA C O CB
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
chi1  N   CA  CB  CG
chi2  CA  CB  CG  SD
chi3  CB  CG  SD  CE
rotamer mmm_19  chi1  -65. chi2  -65. chi3  -70.
rotamer mmt__2  chi1  -65. chi2  -65. chi3  180.
rotamer mmp__3  chi1  -65. chi2  -65. chi3  103.
rotamer mtm_11  chi1  -67. chi2  180. chi3  -75.
rotamer mtt__8  chi1  -67. chi2  180. chi3  180.
rotamer mtp_17  chi1  -67. chi2  180. chi3   75.
rotamer ttm__7  chi1 -177. chi2  180. chi3  -75.
rotamer ttt__3  chi1 -177. chi2  180. chi3  180.
rotamer ttp__5  chi1 -177. chi2  180. chi3   75.
rotamer tpt__2  chi1 -177. chi2   65. chi3  180.
rotamer tpp__5  chi1 -177. chi2   65. chi3   75.
rotamer ptm__3  chi1   62. chi2  180. chi3  -75.
rotamer ptp__2  chi1   62. chi2  180. chi3   75.
TORSION PHI C- N CA C CB C O CG SD CE
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG SD CE 
TORSION CHI2 CA CB CG SD SD CE
TORSION CHI3 CB CG SD CE CE
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    SD    CE
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    SD    CE
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.520 0.02
bond_distance SD   CG      1.803 0.02
bond_distance CE   SD      1.791 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    114.100 2.0
bond_angle SD   CG   CB    112.700 2.0
bond_angle CE   SD   CG    100.900 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    N+    123.000 2.0
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible SD   CG   CB   CA   -170.000 20.
torsion_flexible CE   SD   CG   CB    -70.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue MSE
centre CA
ATOM   N     CA    C     O     CB    CG    SE    CE
fragment_all N     CA    C     O     CB    CG    SE    CE
fragment_mc N     CA    C     O     CB
fragment_sc CB CG  SE  CE
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG SE
fragment_rsr_4 CG  SE  CE
side-chain CB CG  SE  CE
main-chain N CA C O CB
phi   C-  N   CA  C
psi   N   CA  C   N+
omega CA  C   N+  CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
chi1  N   CA  CB  CG
chi2  CA  CB  CG  SE
chi3  CB  CG  SE  CE
rotamer mmm_19  chi1  -65. chi2  -65. chi3  -70.
rotamer mmt__2  chi1  -65. chi2  -65. chi3  180.
rotamer mmp__3  chi1  -65. chi2  -65. chi3  103.
rotamer mtm_11  chi1  -67. chi2  180. chi3  -75.
rotamer mtt__8  chi1  -67. chi2  180. chi3  180.
rotamer mtp_17  chi1  -67. chi2  180. chi3   75.
rotamer ttm__7  chi1 -177. chi2  180. chi3  -75.
rotamer ttt__3  chi1 -177. chi2  180. chi3  180.
rotamer ttp__5  chi1 -177. chi2  180. chi3   75.
rotamer tpt__2  chi1 -177. chi2   65. chi3  180.
rotamer tpp__5  chi1 -177. chi2   65. chi3   75.
rotamer ptm__3  chi1   62. chi2  180. chi3  -75.
rotamer ptp__2  chi1   62. chi2  180. chi3   75.
TORSION PHI C- N CA C CB C O CG SE CE
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG SE CE 
TORSION CHI2 CA CB CG SE SE CE
TORSION CHI3 CB CG SE CE CE
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    SE    CE
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    SE    CE
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.520 0.02
bond_distance SE   CG      1.950 0.02
bond_distance CE   SE      1.951 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    114.100 2.0
bond_angle SE   CG   CB    112.7   2.0
bond_angle CE   SE   CG     98.9   2.0
bond_angle C    CA   N     111.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    N+    123.000 2.0
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible SE   CG   CB   CA   -170.000 20.
torsion_flexible CE   SE   CG   CB    -70.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue PHE 
centre CA
ATOM   N     CA    C     O     CB    CG    CD1   CD2   CE1   CE2 \
      CZ
fragment_all N   CA   C    O    CB   CG    CD1   CD2   CE1   CE2 \
      CZ
fragment_mc N     CA    C     O     CB
fragment_sc CB CG  CD1 CD2 CE1 CE2 CZ
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG  CD1 CD2 CE1 CE2 CZ
side-chain CB CG  CD1 CD2 CE1 CE2 CZ
main-chain N CA C O CB
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
chi1 N CA CB CG
chi2 CA CB CG CD1
rotamer m-85**  chi1  -65. chi2  -85.
rotamer m-30_9  chi1  -65. chi2  -30.
rotamer Sm30__  chi1  -85. chi2   30.
rotamer t80_33  chi1 -177. chi2   80.
rotamer p90_13  chi1   62. chi2   90.
TORSION PHI C- N CA C CB CG CD1 CD2 CE1 CE2 CZ C O
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG CD1 CD2 CE1 CE2 CZ
TORSION CHI2 CA CB CG CD1 CD1 CD2 CE1 CE2 CZ
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD1   CE1   CZ
CONNECT_sc CG    CD2   CE2   CZ
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD1   CE1   CZ
CONNECT_ALL CG    CD2   CE2   CZ
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.502 0.02
bond_distance CD2  CG      1.384 0.02
bond_distance CD1  CG      1.384 0.02
bond_distance CE1  CD1     1.382 0.02
bond_distance CZ   CE1     1.382 0.02
bond_distance CE2  CZ      1.382 0.02
bond_distance CD2  CE2     1.382 0.02
bond_distance CG   CD2     1.382 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    113.800 2.0
bond_angle CD2  CG   CB    120.700 2.0
bond_angle CD1  CG   CB    120.700 2.0
bond_angle CD1  CG   CD2   118.600 2.0
bond_angle CE1  CD1  CG    120.700 2.0
bond_angle CZ   CE1  CD1   120.000 2.0
bond_angle CE2  CZ   CE1   120.000 2.0
bond_angle CD2  CE2  CZ    120.000 2.0
bond_angle CG   CD2  CE2   120.700 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible CD1  CG   CB   CA     90.000 20.
torsion_fixed    CB   CG   CD1  CD2   180.000 2.0
torsion_fixed    CE1  CD1  CG   CB    180.000 2.0
torsion_fixed    CZ   CE1  CD1  CG      0.000 2.0
torsion_fixed    CE2  CZ   CE1  CD1     0.000 2.0
torsion_fixed    CD2  CE2  CZ   CE1     0.000 2.0
torsion_fixed    CG   CD2  CE2  CZ      0.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue PRO 
centre CA
ATOM   N     CA    C     O     CB    CG    CD
fragment_all N     CA    C     O     CB    CG    CD
fragment_mc N     CA    C     O     CB
fragment_sc CB CG CD
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB CG CD C
side-chain CB CG CD
main-chain N CA C O CB
chi1 N CA CB CG
chi2 CA CB CG CD
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer exo_43  chi1  -28. chi2  39. 
rotamer endo44  chi1   28. chi2 -36.
TORSION PSI* N CA C O O 
TORSION CHI1 N CA CB CG CG CD
TORSION CHI2 CA CB CG CD CD
connect_sc -  N CA    +
CONNECT_sc N     CD
CONNECT_sc CA    CB    CG    CD
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL N     CD
CONNECT_ALL CA    CB    CG    CD
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.341 0.02
bond_distance CA   N       1.466 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.492 0.02
bond_distance CD   CG      1.503 0.02
bond_distance CD   N       1.473 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_distance CG   CD      1.503 0.02
bond_angle N    C-   CA-   116.900 2.0
bond_angle CA   N    C-    122.600 2.0
bond_angle CB   CA   N     103.000 2.0
bond_angle CG   CB   CA    104.500 2.0
bond_angle CD   CG   CB    106.100 2.0
bond_angle C    CA   N     111.800 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
bond_angle CD   N    C-    125.000 2.0
bond_angle CG   CD   N     103.200 2.0
!side-chain torsions
torsion_flexible C    N    CA   CD    180.000 20.0
torsion_fixed    N    CA   C    CB   -117.000 2.0
torsion_flexible CG   CB   CA   N      29.000 20.0
torsion_flexible CD   CG   CB   CA    -29.000 20.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -65.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue SER 
centre CA
ATOM   N     CA    C     O     CB    OG
fragment_all N     CA    C     O     CB    OG
fragment_mc N     CA    C     O     CB
fragment_sc CB OG
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG  OG
side-chain CB OG
main-chain N CA C O CB
chi1 N CA CB OG
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m___29  chi1  -65.
rotamer t___22  chi1 -177.
rotamer p___48  chi1   62.
TORSION PHI C- N CA C CB C O OG 
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB OG OG 
connect_sc -  CA    +
CONNECT_sc CA    CB    OG
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    OG
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance OG   CB      1.417 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.700 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle OG   CB   CA    111.100 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
torsion_flexible OG   CB   CA   N      63.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue THR 
centre CA
ATOM   N     CA    C     O     CB    OG1   CG2
fragment_all N     CA    C     O     CB    OG1   CG2
fragment_mc N     CA    C     O     CB
fragment_sc CB OG1  CG2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB OG1  CG2
side-chain CB OG1  CG2
main-chain N CA C O CB
chi1 N CA CB OG1
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m___43  chi1  -65.
rotamer t____7  chi1 -175.
rotamer p___49  chi1   62.
TORSION PHI C- N CA C CB C O OG1 CG2 
TORSION PSI* N CA C O O 
TORSION CHI1 N CA CB OG1 OG1 CG2 
connect_sc -  CA    +
CONNECT_sc CA    CB    OG1
CONNECT_sc CB    CG2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    OG1
CONNECT_ALL CB    CG2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG2  CB      1.521 0.02
bond_distance OG1  CB      1.433 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     111.500 2.0
bond_angle CG2  CB   CA    110.500 2.0
bond_angle OG1  CB   CA    109.600 2.0
bond_angle OG1  CB   CG2   110.000 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
torsion_fixed    CA   CB   OG1  CG2  -121.000 2.0
torsion_flexible OG1  CB   CA   N     -60.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue TRP 
centre CA
ATOM   N     CA    C     O     CB    CG    CD1   CD2   NE1   CE2 \
       CE3   CZ2   CZ3   CH2
fragment_all N     CA    C     O     CB    CG    CD1   CD2   NE1   CE2 \
       CE3   CZ2   CZ3   CH2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG  CD1 CD2 NE1 CE2 CE3 CZ2 CZ3 CH2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG  CD1 CD2 NE1 CE2 CE3 CZ2 CZ3 CH2
side-chain CB CG  CD1 CD2 NE1 CE2 CE3 CZ2 CZ3 CH2
main-chain N CA C O CB
chi1 N CA CB CG
chi2 CA CB CG CD1
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m-90_5  chi1  -65. chi2  -90.
rotamer m0___8  chi1  -65. chi2   -5.
rotamer m95_32  chi1  -65. chi2   95.
rotamer t-105*  chi1 -177. chi2 -105.
rotamer t90_18  chi1 -177. chi2   90.
rotamer p-90**  chi1   62. chi2  -90.
rotamer p90__6  chi1   62. chi2   90.
torsion PHI   C- N CA C CB CG CD1 CD2 NE1 CE2 CE3 CZ2 CZ3 CH2 C O
torsion PSI*  N CA C O O 
torsion CHI1  N CA CB CG CG CD1 CD2 NE1 CE2 CE3 CZ2 CZ3 CH2
torsion CHI2  CA CB CG CD1 CD1 CD2 NE1 CE2 CE3 CZ2 CZ3 CH2
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD1   NE1
CONNECT_sc CG    CD2   CE2   NE1
CONNECT_sc CD2   CE3   CZ3  CH2   CZ2   CE2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD1   NE1
CONNECT_ALL CG    CD2   CE2   NE1
CONNECT_ALL CD2   CE3   CZ3  CH2   CZ2   CE2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.498 0.02
bond_distance CD2  CG      1.433 0.02
bond_distance CD1  CG      1.365 0.02
bond_distance NE1  CD1     1.374 0.02
bond_distance CE2  NE1     1.370 0.02
bond_distance CZ2  CE2     1.394 0.02
bond_distance CD2  CE2     1.409 0.02
bond_distance CG   CD2     1.433 0.02
bond_distance CE3  CD2     1.398 0.02
bond_distance CZ3  CE3     1.382 0.02
bond_distance CH2  CZ3     1.400 0.02
bond_distance CZ2  CH2     1.368 0.02
bond_distance CE2  CZ2     1.394 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    113.600 2.0
bond_angle CD2  CG   CB    126.800 2.0
bond_angle CD1  CG   CB    126.900 2.0
bond_angle CD1  CG   CD2   106.300 2.0
bond_angle NE1  CD1  CG    110.200 2.0
bond_angle CE2  NE1  CD1   108.900 2.0
bond_angle CZ2  CE2  NE1   130.100 2.0
bond_angle CD2  CE2  NE1   107.400 2.0
bond_angle CG   CD2  CE2   107.200 2.0
bond_angle CE3  CD2  CE2   118.800 2.0
bond_angle CZ3  CE3  CD2   118.600 2.0
bond_angle CH2  CZ3  CE3   121.100 2.0
bond_angle CZ2  CH2  CZ3   121.500 2.0
bond_angle CE2  CZ2  CH2   117.500 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible CD1  CG   CB   CA    100.000 20.
torsion_fixed    CB   CG   CD1  CD2   180.000 2.0
torsion_fixed    NE1  CD1  CG   CB    180.000 2.0
torsion_fixed    CE2  NE1  CD1  CG      0.000 2.0
torsion_fixed    NE1  CE2  CD2  CZ2   180.000 2.0
torsion_fixed    CD2  CE2  NE1  CD1     0.000 2.0
torsion_fixed    CE2  CD2  CE3  CG    180.000 2.0
torsion_fixed    CE3  CD2  CE2  NE1   180.000 2.0
torsion_fixed    CZ3  CE3  CD2  CE2     0.000 2.0
torsion_fixed    CZ3  CE3  CD2  CG    180.000 2.0
torsion_fixed    CH2  CZ3  CE3  CD2     0.000 2.0
torsion_fixed    CH2  CZ2  CE2  NE1   180.000 2.0
torsion_fixed    CZ2  CH2  CZ3  CE3     0.000 2.0
torsion_fixed    CE2  CZ2  CH2  CZ3     0.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue TYR 
centre CA
ATOM   N     CA    C     O     CB    CG    CD1   CD2   CE1   CE2 CZ OH
fragment_all  N    CA   C    O    CB   CG   CD1  CD2   CE1   CE2 CZ OH
fragment_mc N     CA    C     O     CB
fragment_sc CB CG  CD1 CD2 CE1 CE2 CZ OH
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG  CD1 CD2 CE1 CE2 CZ OH
side-chain CB CG  CD1 CD2 CE1 CE2 CZ OH
main-chain N CA C O CB
chi1 N CA CB CG
chi2 CA CB CG CD1
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m-85**  chi1  -65. chi2  -85.
rotamer m-30_9  chi1  -65. chi2  -30.
rotamer Sm30__  chi1  -85. chi2   30.
rotamer t80_34  chi1 -177. chi2   80.
rotamer p90_13  chi1   62. chi2   90.
TORSION PHI C- N CA C CB CG CD1 CD2 CE1 CE2 CZ OH C O
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG CG CD1 CD2 CE1 CE2 CZ OH
TORSION CHI2 CA CB CG CD1 CD1 CD2 CE1 CE2 CZ OH
connect_sc -  CA    +
CONNECT_sc CA    CB    CG    CD1   CE1   CZ    OH
CONNECT_sc CG    CD2   CE2   CZ
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    CD1   CE1   CZ    OH
CONNECT_ALL CG    CD2   CE2   CZ
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.512 0.02
bond_distance CD2  CG      1.389 0.02
bond_distance CD1  CG      1.389 0.02
bond_distance CE1  CD1     1.382 0.02
bond_distance CZ   CE1     1.378 0.02
bond_distance OH   CZ      1.376 0.02
bond_distance CE2  CZ      1.378 0.02
bond_distance CD2  CE2     1.382 0.02
bond_distance CG   CD2     1.389 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    113.900 2.0
bond_angle CD2  CG   CB    120.800 2.0
bond_angle CD1  CG   CB    120.800 2.0
bond_angle CD1  CG   CD2   118.400 2.0
bond_angle CE1  CD1  CG    121.200 2.0
bond_angle CZ   CE1  CD1   119.600 2.0
bond_angle OH   CZ   CE1   119.900 2.0
bond_angle CE2  CZ   CE1   120.300 2.0
bond_angle CE2  CZ   OH    119.800 2.0
bond_angle CD2  CE2  CZ    119.600 2.0
bond_angle CG   CD2  CE2   121.200 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
torsion_flexible CD1  CG   CB   CA     90.000 20.
torsion_fixed    CB   CG   CD1  CD2   180.000 2.0
torsion_fixed    CE1  CD1  CG   CB    180.000 2.0
torsion_fixed    CZ   CE1  CD1  CG      0.000 2.0
torsion_fixed    CE1  CZ   CE2  OH    180.000 2.0
torsion_fixed    CE2  CZ   CE1  CD1     0.000 2.0
torsion_fixed    CD2  CE2  CZ   CE1     0.000 2.0
torsion_fixed    CG   CD2  CE2  CZ      0.000 2.0
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
residue VAL 
centre CA
ATOM   N     CA    C     O     CB    CG1   CG2
fragment_all N     CA    C     O     CB    CG1   CG2
fragment_mc N     CA    C     O     CB
fragment_sc CB CG1 CG2
fragment_rsr_1 CA C O N+ CA+
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG1 CG2
side-chain CB CG1 CG2
main-chain N CA C O CB
chi1 N CA CB CG1
phi C- N CA C
psi N CA C N+
omega CA C N+ CA+
conformer alpha phi -55. psi -50.
conformer beta phi -120. psi 120.
rotamer m___20  chi1  -60.
rotamer t___73  chi1  175.
rotamer p____6  chi1   63.
TORSION PHI C- N CA C CB C O CG1 CG2
TORSION PSI* N CA C O O
TORSION CHI1 N CA CB CG1 CG1 CG2 
connect_sc -  CA    +
CONNECT_sc CA    CB    CG1
CONNECT_sc CB    CG2
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG1
CONNECT_ALL CB    CG2
CONNECT_ALL C     O
connect_mc -     N     CA    C     +
connect_mc C     O
bond_distance N    C-      1.329 0.02
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.540 0.02
bond_distance CG1  CB      1.521 0.02
bond_distance CG2  CB      1.521 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle N    C-   CA-   116.200 2.0
bond_angle CA   N    C-    121.200 2.0
bond_angle CB   CA   N     111.500 2.0
bond_angle CG1  CB   CA    110.500 2.0
bond_angle CG2  CB   CA    110.500 2.0
bond_angle CG1  CB   CG2   110.5   2.
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
bond_angle O    C    N+    123.000 2.0
!side-chain torsions
torsion_fixed    CA   CB   CG1  CG2   123.000 2.0
torsion_flexible CG1  CB   CA   N     175.000 20.
!main-chain torsions
torsion_fixed    CA   C    N+   CA+   180.000 2.0
torsion_fixed    N    CA   C    CB   -123.000 2.0
torsion_fixed    CA   C    N+   O     180.000 2.0
torsion_flexible C-   N    CA   C     -55.000 20.
torsion_flexible N    CA   C    N+    -50.000 20.
------------------------------------------------------------------------
RESIDUE HOH
ATOM O
fragment_all O
fragment_rsr_1 O 
CONNECT_ALL O O
CONNECT_mc O O
CONNECT_sc O O
------------------------------------------------------------------------
RESIDUE SOL
ATOM   OHH
fragment_all OHH
fragment_rsr_1 OHH
CONNECT_ALL OHH   OHH
CONNECT_mc OHH OHH
CONNECT_sc OHH OHH
------------------------------------------------------------------------
RESIDUE MG
ATOM   MG
fragment_all MG
fragment_rsr_1 MG
CONNECT_ALL MG   MG
CONNECT_mc MG MG
CONNECT_sc MG MG
------------------------------------------------------------------------
RESIDUE CL
ATOM   CL
fragment_all CL
fragment_rsr_1 CL
CONNECT_ALL CL   CL
CONNECT_mc CL CL
CONNECT_sc CL CL
------------------------------------------------------------------------
residue NAD
ATOM N9A C8A C4A C5A N7A C8A N9A N3A C2A N1A C6A N10A C1R O5R C4R \
     C2R C3R O3R C5R O6R PA OP1A OP2A OP3 PN OP1N OP2N O6Q C5Q C4Q \
     O5Q O3Q C3Q C2Q C1Q N1N C2N C3N C4N C5N C6N C7N O1N N2N
bond_distance N9A  C8A     1.360 0.02
bond_distance C4A  N9A     1.380 0.02
bond_distance C5A  C4A     1.380 0.02
bond_distance N7A  C5A     1.380 0.02
bond_distance C8A  N7A     1.330 0.02
bond_distance N9A  C8A     1.360 0.02
bond_distance N3A  C4A     1.350 0.02
bond_distance C2A  N3A     1.300 0.02
bond_distance N1A  C2A     1.370 0.02
bond_distance C6A  N1A     1.360 0.02
bond_distance N10A C6A     1.330 0.02
bond_distance C5A  C6A     1.410 0.02
bond_distance N1A  C6A     1.360 0.02
bond_distance C2A  N1A     1.370 0.02
bond_distance C1R  N9A     1.460 0.02
bond_distance O5R  C1R     1.400 0.02
bond_distance C4R  O5R     1.450 0.02
bond_distance C2R  C1R     1.520 0.02
bond_distance O2R  C2R     1.440 0.02
bond_distance C3R  C2R     1.530 0.02
bond_distance O3R  C3R     1.440 0.02
bond_distance C4R  C3R     1.520 0.02
bond_distance O5R  C4R     1.450 0.02
bond_distance C5R  C4R     1.510 0.02
bond_distance O6R  C5R     1.440 0.02
bond_distance PA   O6R     1.600 0.02
bond_distance OP1A PA      1.480 0.02
bond_distance OP2A PA      1.480 0.02
bond_distance OP3  PA      1.560 0.02
bond_distance PN   OP3     1.650 0.02
bond_distance OP1N PN      1.480 0.02
bond_distance OP2N PN      1.480 0.02
bond_distance O6Q  PN      1.600 0.02
bond_distance C5Q  O6Q     1.440 0.02
bond_distance C4Q  C5Q     1.510 0.02
bond_distance O5Q  C4Q     1.450 0.02
bond_distance C1Q  O5Q     1.400 0.02
bond_distance C3Q  C4Q     1.520 0.02
bond_distance O3Q  C3Q     1.440 0.02
bond_distance C2Q  C3Q     1.530 0.02
bond_distance O2Q  C2Q     1.440 0.02
bond_distance C1Q  C2Q     1.520 0.02
bond_distance O5Q  C1Q     1.400 0.02
bond_distance C4Q  O5Q     1.450 0.02
bond_distance N1N  C1Q     1.470 0.02
bond_distance C6N  N1N     1.390 0.02
bond_distance C5N  C6N     1.360 0.02
bond_distance C4N  C5N     1.400 0.02
bond_distance C3N  C4N     1.420 0.02
bond_distance C2N  C3N     1.370 0.02
bond_distance C2N  N1N     1.350 0.02
bond_distance C3N  C2N     1.370 0.02
bond_distance C4N  C3N     1.420 0.02
bond_distance C5N  C4N     1.400 0.02
bond_distance C7N  C3N     1.580 0.02
bond_distance O1N  C7N     1.220 0.02
bond_distance N2N  C7N     1.350 0.02
bond_angle C4A  N9A  C8A   106.000 2.0
bond_angle C5A  C4A  N9A   106.000 2.0
bond_angle N7A  C5A  C4A   111.000 2.0
bond_angle C8A  N7A  C5A   104.000 2.0
bond_angle N9A  C8A  N7A   113.000 2.0
bond_angle N3A  C4A  N9A   127.000 2.0
bond_angle C2A  N3A  C4A   111.000 2.0
bond_angle N1A  C2A  N3A   129.000 2.0
bond_angle C6A  N1A  C2A   119.000 2.0
bond_angle N10A C6A  N1A   119.000 2.0
bond_angle C5A  C6A  N1A   117.000 2.0
bond_angle C6A  C5A  C4A   117.000 2.0
bond_angle N1A  C6A  C5A   117.000 2.0
bond_angle C2A  N1A  C6A   119.000 2.0
bond_angle C1R  N9A  C8A   129.000 2.0
bond_angle O5R  C1R  N9A   111.000 2.0
bond_angle C4R  O5R  C1R   110.000 2.0
bond_angle C2R  C1R  N9A   113.000 2.0
bond_angle O2R  C2R  C1R   111.000 2.0
bond_angle C3R  C2R  C1R   103.000 2.0
bond_angle O3R  C3R  C4R   116.000 2.0
bond_angle O3R  C3R  C2R   116.000 2.0
bond_angle C4R  C3R  C2R   100.000 2.0
bond_angle O5R  C4R  C3R   105.000 2.0
bond_angle C1R  O5R  C4R   110.000 2.0
bond_angle C5R  C4R  C3R   116.000 2.0
bond_angle O6R  C5R  C4R   110.000 2.0
bond_angle PA   O6R  C5R   119.000 2.0
bond_angle OP1A PA   O6R   110.000 2.0
bond_angle OP2A PA   O6R   110.000 2.0
bond_angle OP3  PA   O6R   101.000 2.0
bond_angle PN   OP3  PA    133.000 2.0
bond_angle OP1N PN   OP3   110.000 2.0
bond_angle OP2N PN   OP3   110.000 2.0
bond_angle O6Q  PN   OP3   101.000 2.0
bond_angle C5Q  O6Q  PN    119.000 2.0
bond_angle C4Q  C5Q  O6Q   110.000 2.0
bond_angle O5Q  C4Q  C5Q   109.000 2.0
bond_angle C1Q  O5Q  C4Q   110.000 2.0
bond_angle C3Q  C4Q  C5Q   116.000 2.0
bond_angle O3Q  C3Q  C4Q   115.000 2.0
bond_angle O3Q  C3Q  C2Q   115.000 2.0
bond_angle C2Q  C3Q  C4Q   100.000 2.0
bond_angle O2Q  C2Q  C3Q   108.000 2.0
bond_angle C1Q  C2Q  C3Q   103.000 2.0
bond_angle O5Q  C1Q  C2Q   106.000 2.0
bond_angle C4Q  O5Q  C1Q   110.000 2.0
bond_angle N1N  C1Q  C2Q   113.000 2.0
bond_angle C6N  N1N  C1Q   120.000 2.0
bond_angle C5N  C6N  N1N   113.000 2.0
bond_angle C4N  C5N  C6N   128.000 2.0
bond_angle C3N  C4N  C5N   113.000 2.0
bond_angle C2N  C3N  C4N   123.000 2.0
bond_angle C2N  N1N  C1Q   120.000 2.0
bond_angle C3N  C2N  N1N   120.000 2.0
bond_angle C4N  C3N  C2N   123.000 2.0
bond_angle C5N  C4N  C3N   113.000 2.0
bond_angle C7N  C3N  C2N   122.000 2.0
bond_angle O1N  C7N  C3N   120.000 2.0
bond_angle N2N  C7N  C3N   116.000 2.0
torsion_fixed C8A  N9A  C1R  C4A   180.000 2.0
torsion_fixed N9A  C4A  N3A  C5A   180.000 2.0
torsion_fixed C4A  C5A  C6A  N7A   180.000 2.0
torsion_fixed C8A  N7A  C5A  C4A     0.000 2.0
torsion_fixed N9A  C8A  N7A  C5A     0.000 2.0
torsion_fixed N3A  C4A  N9A  C8A   180.000 2.0
torsion_fixed C2A  N3A  C4A  N9A   180.000 2.0
torsion_fixed N1A  C2A  N3A  C4A     0.000 2.0
torsion_fixed C6A  N1A  C2A  N3A     0.000 2.0
torsion_fixed N1A  C6A  C5A  N10A  180.000 2.0
torsion_fixed C5A  C6A  N1A  C2A     0.000 2.0
torsion_fixed C6A  C5A  C4A  N9A   180.000 2.0
torsion_fixed N1A  C6A  C5A  C4A     0.000 2.0
torsion_fixed C2A  N1A  C6A  C5A     0.000 2.0
torsion_fixed N9A  C1R  C2R  O5R   120.000 2.0
torsion_fixed C4R  O5R  C1R  N9A  -144.000 2.0
torsion_flexible C2R  C1R  N9A  C8A     0.000 20.
torsion_fixed C1R  C2R  C3R  O2R   120.000 2.0
torsion_fixed C3R  C2R  C1R  N9A   157.000 2.0
torsion_fixed C2R  C3R  C4R  O3R   120.000 2.0
torsion_fixed C4R  C3R  C2R  C1R   -35.000 2.0
torsion_fixed C3R  C4R  C5R  O5R   120.000 2.0
torsion_fixed C1R  O5R  C4R  C3R     0.000 2.0
torsion_fixed C5R  C4R  C3R  C2R   -98.000 2.0
torsion_flexible O6R  C5R  C4R  C3R   180.000 20.
torsion_flexible PA   O6R  C5R  C4R   180.000 20.
torsion_fixed O6R  PA   OP3  OP1A -120.000 2.0
torsion_fixed O6R  PA   OP3  OP2A  120.000 2.0
torsion_flexible OP3  PA   O6R  C5R   180.000 20.
torsion_flexible PN   OP3  PA   O6R   180.000 20.
torsion_fixed OP3  PN   O6Q  OP1N -120.000 2.0
torsion_fixed OP3  PN   O6Q  OP2N  120.000 2.0
torsion_flexible O6Q  PN   OP3  PA    180.000 20.
torsion_flexible C5Q  O6Q  PN   OP3   180.000 20.
torsion_flexible C4Q  C5Q  O6Q  PN    180.000 20.
torsion_fixed C5Q  C4Q  C3Q  O5Q  -120.000 2.0
torsion_fixed C1Q  O5Q  C4Q  C5Q   120.000 2.0
torsion_flexible C3Q  C4Q  C5Q  O6Q   180.000 20.
torsion_fixed C4Q  C3Q  C2Q  O3Q  -120.000 2.0
torsion_fixed C2Q  C3Q  C4Q  C5Q   -98.000 2.0
torsion_fixed C3Q  C2Q  C1Q  O2Q  -120.000 2.0
torsion_fixed C1Q  C2Q  C3Q  C4Q   -36.000 2.0
torsion_fixed C2Q  C1Q  N1N  O5Q  -120.000 2.0
torsion_fixed C4Q  O5Q  C1Q  C2Q   -24.000 2.0
torsion_fixed N1N  C1Q  C2Q  C3Q   157.000 2.0
torsion_fixed C1Q  N1N  C2N  C6N   180.000 2.0
torsion_fixed C5N  C6N  N1N  C1Q   180.000 2.0
torsion_fixed C4N  C5N  C6N  N1N     0.000 2.0
torsion_fixed C3N  C4N  C5N  C6N     0.000 2.0
torsion_fixed C2N  C3N  C4N  C5N     0.000 2.0
torsion_flexible C2N  N1N  C1Q  C2Q     0.000 20.
torsion_fixed C3N  C2N  N1N  C1Q   180.000 2.0
torsion_fixed C2N  C3N  C7N  C4N   180.000 2.0
torsion_fixed C5N  C4N  C3N  C2N     0.000 2.0
torsion_fixed C7N  C3N  C2N  N1N   180.000 2.0
torsion_fixed C3N  C7N  N2N  O1N   180.000 2.0
torsion_flexible N2N  C7N  C3N  C2N     0.000 20.
------------------------------------------------------------------------
residue SO4 
ATOM S O1 O2 O3 O4
centre S
connect_all S O1
connect_all S O2
connect_all S O3
connect_all S O4
connect_mc S O1
connect_mc S O2
connect_mc S O3
connect_mc S O4
connect_sc S O1
connect_sc S O2
connect_sc S O3
connect_sc S O4
fragment_all S O1 O2 O3 O4
fragment_rsr_1 S O1 O2 O3 O4
bond_distance O1   S       1.450 0.02
bond_distance O2   S       1.450 0.02
bond_distance O3   S       1.450 0.02
bond_distance O4   S       1.450 0.02
bond_angle    O1   S   O2  110. 2.
bond_angle    O1   S   O3  110. 2.
bond_angle    O1   S   O4  110. 2.
bond_angle    O2   S   O3  110. 2.
bond_angle    O2   S   O4  110. 2.
bond_angle    O3   S   O4  110. 2.
torsion_fixed O2 S O1 O4  120. 2.
torsion_fixed O2 S O1 O3 -120. 2.
------------------------------------------------------------------------
---- here come my standard nucleic acids
------------------------------------------------------------------------
residue A
centre P
ATOM   P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 N3 C4 C5 C6 N6 N7 C8 N9
fragment_all P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 N3 C4 C5 C6 N6 N7 C8 N9
fragment_mc P O1P O2P O5* C5* C4* C3* O3* C2* O2* C1* O4*
fragment_sc N1 C2 N3 C4 C5 C6 N6 N7 C8 N9
side-chain N1 C2 N3 C4 C5 C6 N6 N7 C8 N9 O2* C1* O4* C2* 
main-chain P O1P O2P O5* C5* C4* C3* O3* 
alpha   O3*- P    O5*  C5*
beta    P    O5*  C5*  C4*
gamma   O5*  C5*  C4*  C3*
delta   C5*  C4*  C3*  O3*
epsilon C4*  C3*  O3*  P+
zeta    C3*  O3*  P+   O5*+
chi     O4*  C1*  N9   C4
nu0     C4*  O4*  C1*  C2*
nu1     O4*  C1*  C2*  C3*
nu2     C1*  C2*  C3*  C4*
nu3     C2*  C3*  C4*  O4*
nu4     C3*  C4*  O4*  C1*
rotamer 1 chi -152. nu2  37. nu3 -36 nu4 26.
rotamer 2 chi   28. nu2  37. nu3 -36 nu4 26.
rotamer 1 chi   28. nu2 -34. nu3  24 nu4 -3.
rotamer 2 chi -152. nu2 -34. nu3  24 nu4 -3.
conformer helix alpha -68.
torsion CHI  O4* C1* N9 C8 C8 C4 C5 N7 N3 C2 N1 C6 N6
torsion GAMMA*  O4* C4* C5* O5* O5* P O1P O2P
torsion BETA C4* C5* O5* P P O1P O2P
torsion ALPHA* C5* O5* P O1P O1P O2P
torsion CHI* C8 N9 C1* O4* O4* C4* C3* O3* C2* O2* C5* O5* \
             P O1P O2P
torsion GAMMA O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N9 C8 \
              C4 C5 N7 N3 C2 N1 C6 N6
CONNECT_ALL - P O5* C5* C4* C3* O3* +
CONNECT_ALL C4* O4* C1* C2* C3*
CONNECT_ALL C2* O2*
CONNECT_ALL C1* N9 C4 C5 N7 C8 N9
CONNECT_ALL C4 N3 C2 N1 C6 C5
CONNECT_ALL C6 N6
CONNECT_ALL P O1P
CONNECT_ALL P O2P
! sugar-phosphate bonds
bond_distance P    O3*-    1.590 0.02
bond_distance O1P  P       1.480 0.02
bond_distance O2P  P       1.480 0.02
bond_distance O5*  P       1.600 0.02
bond_distance C5*  O5*     1.440 0.02
bond_distance C4*  C5*     1.510 0.02
bond_distance O4*  C4*     1.450 0.02
bond_distance C1*  O4*     1.410 0.02
bond_distance C2*  C1*     1.530 0.02
bond_distance C3*  C4*     1.520 0.02
bond_distance C2*  C3*     1.530 0.02
bond_distance O2*  C2*     1.420 0.02
bond_distance O3*  C3*     1.420 0.02
! base bonds
bond_distance N9   C1*     1.480 0.02
bond_distance C4   N9      1.370 0.02
bond_distance C8   N9      1.360 0.02
bond_distance N7   C8      1.300 0.02
bond_distance C5   N7      1.380 0.02
bond_distance C4   C5      1.370 0.02
bond_distance C6   C5      1.410 0.02
bond_distance N6   C6      1.350 0.02
bond_distance N1   C6      1.340 0.02
bond_distance C2   N1      1.340 0.02
bond_distance N3   C2      1.320 0.02
bond_distance C4   N3      1.340 0.02
bond_distance C5   C4      1.370 0.02
bond_distance N9   C4      1.370 0.02
!sugar-phosphate angles
bond_angle P    O3*- C3*-  119.000 2.0
bond_angle O1P  P    O3*-  110.000 2.0
bond_angle O2P  P    O3*-  110.000 2.0
bond_angle O1P  P    O5*   110.000 2.0
bond_angle O2P  P    O5*   110.000 2.0
bond_angle O1P  P    O2P   110.000 2.0
bond_angle O5*  P    O3*-  102.000 2.0
bond_angle C5*  O5*  P     118.000 2.0
bond_angle C4*  C5*  O5*   110.000 2.0
bond_angle O4*  C4*  C5*   110.000 2.0
bond_angle C1*  O4*  C4*   110.000 2.0
bond_angle C2*  C1*  O4*   107.000 2.0
bond_angle C3*  C4*  C5*   116.000 2.0
bond_angle C2*  C3*  C4*   102.000 2.0
bond_angle O2*  C2*  C3*   114.000 2.0
bond_angle O2*  C2*  C1*   114.000 2.0
bond_angle C1*  C2*  C3*   101.000 2.0
bond_angle O3*  C3*  C4*   112.000 2.0
bond_angle C2*  C3*  O3*   114.000 2.0
! base angles
bond_angle N9   C1*  O4*   109.000 2.0
bond_angle C4   N9   C1*   126.000 2.0
bond_angle C8   N9   C1*   128.000 2.0
bond_angle N7   C8   N9    114.000 2.0
bond_angle C5   N7   C8    104.000 2.0
bond_angle C4   C5   N7    111.000 2.0
bond_angle C6   C5   N7    133.000 2.0
bond_angle N6   C6   C5    123.000 2.0
bond_angle N1   C6   C5    118.000 2.0
bond_angle C2   N1   C6    119.000 2.0
bond_angle N3   C2   N1    129.000 2.0
bond_angle C4   N3   C2    110.000 2.0
bond_angle C5   C4   N3    128.000 2.0
bond_angle N9   C4   N3    126.000 2.0
!flexible sugar-phosphate
torsion_flexible O1P  P    O5*  C5*   180.000 20. DUMMY 
torsion_flexible O2P  P    O5*  C5*    60.000 20. DUMMY
torsion_flexible C5*  O5*  P    O3*-  -68.000 20. alpha
torsion_flexible C4*  C5*  O5*  P     178.000 20. beta
torsion_flexible C3*  C4*  C5*  O5*    54.000 20. gamma
!torsion_flexible O3*  C3*  C4*  C5*    82.000 20. delta
torsion_flexible P+   O3*  C3*  C4*  -153.000 20. epsilon
torsion_flexible O5*+ P+   O3*  C3*   -71.000 20. zeta
!sugar-phosphate branches
torsion_fixed    O3*-  P    O5*  O1P   120.000 2.0 branch P
torsion_fixed    O3*-  P    O5*  O2P  -120.000 2.0 branch P
torsion_fixed    C5*   C4*  C3*  O4*  -120.000 2.0 branch C4*
torsion_fixed    O4*   C1*  N9   C2*   120.000 2.0 branch C1*
torsion_fixed    C4*   C3*  O3*  C2*   120.000 2.0 branch C3*
torsion_fixed    C3*   C2*  C1*  O2*  -120.000 2.0 branch C2*
!base torsions, including glycosylic
torsion_flexible C4    N9   C1*  O4*  -158.000 20.  chi
torsion_fixed    C1*   N9   C4   C8    180.000 2.0 branch N9
torsion_fixed    N7    C8   N9   C4      0.000 2.0
torsion_fixed    C5    N7   C8   N9      0.000 2.0
torsion_fixed    N7    C5   C6   C4    180.000 2.0 branch C5
torsion_fixed    C6    C5   N7   C8    180.000 2.0
torsion_fixed    C5    C6   N1   N6    180.000 2.0 branch C6
torsion_fixed    N1    C6   C5   N7    180.000 2.0
torsion_fixed    C2    N1   C6   C5      0.000 2.0
torsion_fixed    N3    C2   N1   C6      0.000 2.0
torsion_fixed    C4    N3   C2   N1      0.000 2.0
torsion_fixed    N3    C4   N9   C5    180.000 2.0 branch C4
torsion_fixed    N9    C4   N3   C2    180.000 2.0
! sugar pucker, flexible (Phil Evans` advice). note Delta is flagged as flexible
torsion_flexible    C1*   C2*  C3*  C4*    37.    2.0 nu2
torsion_flexible    C2*   C3*  C4*  O4*   -36.    2.0 nu3
torsion_flexible    C3*   C4*  O4*  C1*    26.    2.0 nu4
------------------------------------------------------------------------
residue G
centre P
ATOM   P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 N2 N3 C4 C5 C6 O6 N7 C8 N9
fragment_all P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 N2 N3 C4 C5 C6 O6 N7 C8 N9
fragment_mc P O1P O2P O5* C5* C4* C3* O3* C2* O2* C1* O4*
fragment_sc N1 C2 N2 N3 C4 C5 C6 O6 N7 C8 N9
side-chain N1 C2 N2 N3 C4 C5 C6 O6 N7 C8 N9 C2* O2* C1* O4*
main-chain P O1P O2P O5* C5* C4* C3* O3* 
alpha   O3*- P    O5*  C5*
beta    P    O5*  C5*  C4*
gamma   O5*  C5*  C4*  C3*
delta   C5*  C4*  C3*  O3*
epsilon C4*  C3*  O3*  P+
zeta    C3*  O3*  P+   O5*+
chi     O4*  C1*  N9   C4
nu0     C4*  O4*  C1*  C2*
nu1     O4*  C1*  C2*  C3*
nu2     C1*  C2*  C3*  C4*
nu3     C2*  C3*  C4*  O4*
nu4     C3*  C4*  O4*  C1*
rotamer 1 chi -152. nu2  37. nu3 -36 nu4 26.
rotamer 2 chi   28. nu2  37. nu3 -36 nu4 26.
rotamer 1 chi   28. nu2 -34. nu3  24 nu4 -3.
rotamer 2 chi -152. nu2 -34. nu3  24 nu4 -3.
conformer helix alpha -68.
torsion CHI  O4* C1* N9 C8 C8 C4 C5 N7 N3 C2 N1 C6 O6 N2
torsion GAMMA*  O4* C4* C5* O5* O5* P O1P O2P
torsion BETA C4* C5* O5* P P O1P O2P
torsion ALPHA* C5* O5* P O1P O1P O2P
torsion CHI* C8 N9 C1* O4* O4* C4* C3* O3* C2* O2* C5* O5* \
             P O1P O2P
torsion GAMMA O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N9 C8 \
              C4 C5 N7 N3 C2 N1 C6 O6 N2
CONNECT_ALL - P O5* C5* C4* C3* O3* +
CONNECT_ALL C4* O4* C1* C2* C3*
CONNECT_ALL C2* O2*
CONNECT_ALL C1* N9 C4 C5 N7 C8 N9
CONNECT_ALL C4 N3 C2 N1 C6 C5
CONNECT_ALL C2 N2
CONNECT_ALL C6 O6
CONNECT_ALL P O1P
CONNECT_ALL P O2P
! sugar-phosphate bonds
bond_distance P    O3*-    1.590 0.02
bond_distance O1P  P       1.480 0.02
bond_distance O2P  P       1.480 0.02
bond_distance O5*  P       1.600 0.02
bond_distance C5*  O5*     1.440 0.02
bond_distance C4*  C5*     1.510 0.02
bond_distance O4*  C4*     1.450 0.02
bond_distance C1*  O4*     1.410 0.02
bond_distance C2*  C1*     1.530 0.02
bond_distance C3*  C4*     1.520 0.02
bond_distance C2*  C3*     1.530 0.02
bond_distance O2*  C2*     1.420 0.02
bond_distance O3*  C3*     1.420 0.02
! base bonds
bond_distance N9   C1*     1.480 0.02
bond_distance C4   N9      1.380 0.02
bond_distance C8   N9      1.380 0.02
bond_distance N7   C8      1.310 0.02
bond_distance C5   N7      1.390 0.02
bond_distance C4   C5      1.370 0.02
bond_distance C6   C5      1.420 0.02
bond_distance O6   C6      1.230 0.02
bond_distance N1   C6      1.400 0.02
bond_distance C2   N1      1.390 0.02
bond_distance N2   C2      1.330 0.02
bond_distance N3   C2      1.320 0.02
bond_distance C4   N3      1.360 0.02
bond_distance C5   C4      1.370 0.02
bond_distance N9   C4      1.380 0.02
!sugar-phosphate angles
bond_angle P    O3*- C3*-  119.000 2.0
bond_angle O1P  P    O3*-  110.000 2.0
bond_angle O2P  P    O3*-  110.000 2.0
bond_angle O1P  P    O5*   110.000 2.0
bond_angle O2P  P    O5*   110.000 2.0
bond_angle O1P  P    O2P   110.000 2.0
bond_angle O5*  P    O3*-  102.000 2.0
bond_angle C5*  O5*  P     118.000 2.0
bond_angle C4*  C5*  O5*   110.000 2.0
bond_angle O4*  C4*  C5*   110.000 2.0
bond_angle C1*  O4*  C4*   110.000 2.0
bond_angle C2*  C1*  O4*   107.000 2.0
bond_angle C3*  C4*  C5*   116.000 2.0
bond_angle C2*  C3*  C4*   102.000 2.0
bond_angle O2*  C2*  C3*   114.000 2.0
bond_angle O2*  C2*  C1*   114.000 2.0
bond_angle C1*  C2*  C3*   101.000 2.0
bond_angle O3*  C3*  C4*   112.000 2.0
bond_angle C2*  C3*  O3*   114.000 2.0
! base angles
bond_angle N9   C1*  O4*   108.000 2.0
bond_angle C4   N9   C1*   126.000 2.0
bond_angle C8   N9   C1*   129.000 2.0
bond_angle N7   C8   N9    114.000 2.0
bond_angle C5   N7   C8    104.000 2.0
bond_angle C4   C5   N7    111.000 2.0
bond_angle C6   C5   N7    130.000 2.0
bond_angle O6   C6   C5    129.000 2.0
bond_angle N1   C6   C5    111.000 2.0
bond_angle C2   N1   C6    125.000 2.0
bond_angle N2   C2   N1    115.000 2.0
bond_angle N3   C2   N1    124.000 2.0
bond_angle C4   N3   C2    112.000 2.0
bond_angle C5   C4   N3    129.000 2.0
bond_angle N9   C4   N3    125.000 2.0
!flexible sugar-phosphate
torsion_flexible O1P  P    O5*  C5*   180.000 20. DUMMY 
torsion_flexible O2P  P    O5*  C5*    60.000 20. DUMMY
torsion_flexible C5*  O5*  P    O3*-  -68.000 20. alpha
torsion_flexible C4*  C5*  O5*  P     178.000 20. beta
torsion_flexible C3*  C4*  C5*  O5*    54.000 20. gamma
!torsion_flexible O3*  C3*  C4*  C5*    82.000 20. delta
torsion_flexible P+   O3*  C3*  C4*  -153.000 20. epsilon
torsion_flexible O5*+ P+   O3*  C3*   -71.000 20. zeta
!sugar-phosphate branches
torsion_fixed    O3*-  P    O5*  O1P   120.000 2.0 branch P
torsion_fixed    O3*-  P    O5*  O2P  -120.000 2.0 branch P
torsion_fixed    C5*   C4*  C3*  O4*  -120.000 2.0 branch C4*
torsion_fixed    O4*   C1*  N9   C2*   120.000 2.0 branch C1*
torsion_fixed    C4*   C3*  O3*  C2*   120.000 2.0 branch C3*
torsion_fixed    C3*   C2*  C1*  O2*  -120.000 2.0 branch C2*
!base torsions, including glycosylic
torsion_flexible C4    N9   C1*  O4*  -158.000 20.  chi
torsion_fixed    C1*   N9   C4   C8    180.000 2.0 branch N9
torsion_fixed    N7    C8   N9   C4      0.000 2.0
torsion_fixed    C5    N7   C8   N9      0.000 2.0
torsion_fixed    N7    C5   C6   C4    180.000 2.0 branch C5
torsion_fixed    C6    C5   N7   C8    180.000 2.0
torsion_fixed    C5    C6   N1   O6    180.000 2.0 branch C6
torsion_fixed    N1    C6   C5   N7    180.000 2.0
torsion_fixed    C2    N1   C6   C5      0.000 2.0
torsion_fixed    N3    C2   N1   C6      0.000 2.0
torsion_fixed    C4    N3   C2   N1      0.000 2.0
torsion_fixed    N3    C2   N1   N2    180.    2.0 branch C2
torsion_fixed    N3    C4   N9   C5    180.000 2.0 branch C4
torsion_fixed    N9    C4   N3   C2    180.000 2.0
! sugar pucker, flexible (Phil Evans` advice). note Delta is flagged as flexible
torsion_flexible    C1*   C2*  C3*  C4*    37.    2.0 nu2
torsion_flexible    C2*   C3*  C4*  O4*   -36.    2.0 nu3
torsion_flexible    C3*   C4*  O4*  C1*    26.    2.0 nu4
------------------------------------------------------------------------
residue C
centre P
ATOM   P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 O2 N3 C4 N4 C5 C6
fragment_all P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 O2 N3 C4 N4 C5 C6
fragment_mc P O1P O2P O5* C5* C4* C3* O3* C2* O2* C1* O4*
fragment_sc N1 C2 O2 N3 C4 N4 C5 C6
side-chain N1 C2 O2 N3 C4 N4 C5 C6 C2* O2* C1* O4* 
main-chain P O1P O2P O5* C5* C4* C3* O3* 
alpha   O3*- P    O5*  C5*
beta    P    O5*  C5*  C4*
gamma   O5*  C5*  C4*  C3*
delta   C5*  C4*  C3*  O3*
epsilon C4*  C3*  O3*  P+
zeta    C3*  O3*  P+   O5*+
chi     O4*  C1*  N1   C2
nu0     C4*  O4*  C1*  C2*
nu1     O4*  C1*  C2*  C3*
nu2     C1*  C2*  C3*  C4*
nu3     C2*  C3*  C4*  O4*
nu4     C3*  C4*  O4*  C1*
rotamer 1 chi -152. nu2  37. nu3 -36 nu4 26.
rotamer 2 chi   28. nu2  37. nu3 -36 nu4 26.
rotamer 1 chi   28. nu2 -34. nu3  24 nu4 -3.
rotamer 2 chi -152. nu2 -34. nu3  24 nu4 -3.
conformer helix alpha -68.
torsion CHI     O4* C1* N1 C6 C5 C4 N4 N3 C2 O2 C6
torsion GAMMA*  O4* C4* C5* O5* O5* P O1P O2P
torsion BETA    C4* C5* O5* P P O1P O2P
torsion ALPHA*  C5* O5* P O1P O1P O2P
torsion CHI*    C6 N1 C1* O4* O4* C4* C3* O3* C2* O2* C5* O5* \
                P O1P O2P
torsion GAMMA   O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N1 C6 \
                C5 C4 N4 N3 C2 O2
CONNECT_ALL - P O5* C5* C4* C3* O3* +
CONNECT_ALL C4* O4* C1* C2* C3*
CONNECT_ALL C2* O2*
CONNECT_ALL C1* N1 C2 N3 C4 C5 C6 N1
CONNECT_ALL C2 O2
CONNECT_ALL C4 N4
CONNECT_ALL P O1P
CONNECT_ALL P O2P
! sugar-phosphate bonds
bond_distance P    O3*-    1.590 0.02
bond_distance O1P  P       1.480 0.02
bond_distance O2P  P       1.480 0.02
bond_distance O5*  P       1.600 0.02
bond_distance C5*  O5*     1.440 0.02
bond_distance C4*  C5*     1.510 0.02
bond_distance O4*  C4*     1.450 0.02
bond_distance C1*  O4*     1.410 0.02
bond_distance C2*  C1*     1.530 0.02
bond_distance C3*  C4*     1.520 0.02
bond_distance C2*  C3*     1.530 0.02
bond_distance O2*  C2*     1.420 0.02
bond_distance O3*  C3*     1.420 0.02
! base bonds
bond_distance N1   C1*     1.470 0.02
bond_distance C2   N1      1.340 0.02
bond_distance C6   N1      1.360 0.02
bond_distance C5   C6      1.340 0.02
bond_distance C4   C5      1.430 0.02
bond_distance N4   C4      1.340 0.02
bond_distance N3   C4      1.330 0.02
bond_distance C2   N3      1.360 0.02
bond_distance O2   C2      1.240 0.02
bond_distance N1   C2      1.340 0.02
!sugar-phosphate angles
bond_angle P    O3*- C3*-  119.000 2.0
bond_angle O1P  P    O3*-  110.000 2.0
bond_angle O2P  P    O3*-  110.000 2.0
bond_angle O1P  P    O5*   110.000 2.0
bond_angle O2P  P    O5*   110.000 2.0
bond_angle O1P  P    O2P   110.000 2.0
bond_angle O5*  P    O3*-  102.000 2.0
bond_angle C5*  O5*  P     118.000 2.0
bond_angle C4*  C5*  O5*   110.000 2.0
bond_angle O4*  C4*  C5*   110.000 2.0
bond_angle C1*  O4*  C4*   110.000 2.0
bond_angle C2*  C1*  O4*   107.000 2.0
bond_angle C3*  C4*  C5*   116.000 2.0
bond_angle C2*  C3*  C4*   102.000 2.0
bond_angle O2*  C2*  C3*   114.000 2.0
bond_angle O2*  C2*  C1*   114.000 2.0
bond_angle C1*  C2*  C3*   101.000 2.0
bond_angle O3*  C3*  C4*   112.000 2.0
bond_angle C2*  C3*  O3*   114.000 2.0
! base angles
bond_angle N1   C1*  O4*   108.000 2.0
bond_angle C2   N1   C1*   118.000 2.0
bond_angle C6   N1   C1*   121.000 2.0
bond_angle C5   C6   N1    121.000 2.0
bond_angle C4   C5   C6    117.000 2.0
bond_angle N4   C4   C5    122.000 2.0
bond_angle N3   C4   C5    122.000 2.0
bond_angle C2   N3   C4    120.000 2.0
bond_angle O2   C2   N3    122.000 2.0
bond_angle N1   C2   N3    119.000 2.0
!flexible sugar-phosphate
torsion_flexible O1P  P    O5*  C5*   180.000 20. DUMMY 
torsion_flexible O2P  P    O5*  C5*    60.000 20. DUMMY
torsion_flexible C5*  O5*  P    O3*-  -68.000 20. alpha
torsion_flexible C4*  C5*  O5*  P     178.000 20. beta
torsion_flexible C3*  C4*  C5*  O5*    54.000 20. gamma
!torsion_flexible O3*  C3*  C4*  C5*    82.000 20. delta
torsion_flexible P+   O3*  C3*  C4*  -153.000 20. epsilon
torsion_flexible O5*+ P+   O3*  C3*   -71.000 20. zeta
!sugar-phosphate branches
torsion_fixed    O3*-  P    O5*  O1P   120.000 2.0 branch P
torsion_fixed    O3*-  P    O5*  O2P  -120.000 2.0 branch P
torsion_fixed    C5*   C4*  C3*  O4*  -120.000 2.0 branch C4*
torsion_fixed    O4*   C1*  N1   C2*   120.000 2.0 branch C1*
torsion_fixed    C4*   C3*  O3*  C2*   120.000 2.0 branch C3*
torsion_fixed    C3*   C2*  C1*  O2*  -120.000 2.0 branch C2*
!base torsions, including glycosylic
torsion_flexible C2    N1   C1*  O4*  -158.000 20.  chi
torsion_fixed    C1*   N1   C2   C6    180.000 2.0 branch N1
torsion_fixed    C5    C6   N1   C2      0.000 2.0
torsion_fixed    C4    C5   C6   N1      0.000 2.0
torsion_fixed    C5    C4   N3   N4    180.000 2.0 branch C4
torsion_fixed    N3    C4   C5   C6      0.000 2.0
torsion_fixed    C2    N3   C4   C5      0.000 2.0
torsion_fixed    N3    C2   N1   O2    180.000 2.0 branch C2
torsion_fixed    N1    C2   N3   C4      0.000 2.0
! sugar pucker, flexible (Phil Evans` advice). note Delta is flagged as flexible
torsion_flexible    C1*   C2*  C3*  C4*    37.    2.0 nu2
torsion_flexible    C2*   C3*  C4*  O4*   -36.    2.0 nu3
torsion_flexible    C3*   C4*  O4*  C1*    26.    2.0 nu4
------------------------------------------------------------------------
residue U
centre P
ATOM   P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 O2 N3 C4 O4 C5 C6
fragment_all P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 O2 N3 C4 O4 C5 C6
fragment_mc P O1P O2P O5* C5* C4* C3* O3* C2* O2* C1* O4*
fragment_sc N1 C2 O2 N3 C4 O4 C5 C6
side-chain N1 C2 O2 N3 C4 O4 C5 C6 C2* O2* C1* O4* 
main-chain P O1P O2P O5* C5* C4* C3* O3* 
alpha   O3*- P    O5*  C5*
beta    P    O5*  C5*  C4*
gamma   O5*  C5*  C4*  C3*
delta   C5*  C4*  C3*  O3*
epsilon C4*  C3*  O3*  P+
zeta    C3*  O3*  P+   O5*+
chi     O4*  C1*  N1   C2
nu0     C4*  O4*  C1*  C2*
nu1     O4*  C1*  C2*  C3*
nu2     C1*  C2*  C3*  C4*
nu3     C2*  C3*  C4*  O4*
nu4     C3*  C4*  O4*  C1*
rotamer 1 chi -152. nu2  37. nu3 -36 nu4 26.
rotamer 2 chi   28. nu2  37. nu3 -36 nu4 26.
rotamer 1 chi   28. nu2 -34. nu3  24 nu4 -3.
rotamer 2 chi -152. nu2 -34. nu3  24 nu4 -3.
conformer helix alpha -68.
torsion CHI     O4* C1* N1 C6 C5 C4 O4 N3 C2 O2 C6
torsion GAMMA*  O4* C4* C5* O5* O5* P O1P O2P
torsion BETA    C4* C5* O5* P P O1P O2P
torsion ALPHA*  C5* O5* P O1P O1P O2P
torsion CHI*    C6 N1 C1* O4* O4* C4* C3* O3* C2* O2* C5* O5* \
                P O1P O2P
torsion GAMMA   O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N1 C6 \
                C5 C4 O4 N3 C2 O2
CONNECT_ALL - P O5* C5* C4* C3* O3* +
CONNECT_ALL C4* O4* C1* C2* C3*
CONNECT_ALL C2* O2*
CONNECT_ALL C1* N1 C2 N3 C4 C5 C6 N1
CONNECT_ALL C2 O2
CONNECT_ALL C4 O4
CONNECT_ALL P O1P
CONNECT_ALL P O2P
! sugar-phosphate bonds
bond_distance P    O3*-    1.590 0.02
bond_distance O1P  P       1.480 0.02
bond_distance O2P  P       1.480 0.02
bond_distance O5*  P       1.600 0.02
bond_distance C5*  O5*     1.440 0.02
bond_distance C4*  C5*     1.510 0.02
bond_distance O4*  C4*     1.450 0.02
bond_distance C1*  O4*     1.410 0.02
bond_distance C2*  C1*     1.530 0.02
bond_distance C3*  C4*     1.520 0.02
bond_distance C2*  C3*     1.530 0.02
bond_distance O2*  C2*     1.420 0.02
bond_distance O3*  C3*     1.420 0.02
! base bonds
bond_distance N1   C1*     1.470 0.02
bond_distance C2   N1      1.380 0.02
bond_distance C6   N1      1.380 0.02
bond_distance C5   C6      1.340 0.02
bond_distance C4   C5      1.440 0.02
bond_distance O4   C4      1.230 0.02
bond_distance N3   C4      1.380 0.02
bond_distance C2   N3      1.370 0.02
bond_distance O2   C2      1.220 0.02
bond_distance N1   C2      1.380 0.02
!sugar-phosphate angles
bond_angle P    O3*- C3*-  119.000 2.0
bond_angle O1P  P    O3*-  110.000 2.0
bond_angle O2P  P    O3*-  110.000 2.0
bond_angle O1P  P    O5*   110.000 2.0
bond_angle O2P  P    O5*   110.000 2.0
bond_angle O1P  P    O2P   110.000 2.0
bond_angle O5*  P    O3*-  102.000 2.0
bond_angle C5*  O5*  P     118.000 2.0
bond_angle C4*  C5*  O5*   110.000 2.0
bond_angle O4*  C4*  C5*   110.000 2.0
bond_angle C1*  O4*  C4*   110.000 2.0
bond_angle C2*  C1*  O4*   107.000 2.0
bond_angle C3*  C4*  C5*   116.000 2.0
bond_angle C2*  C3*  C4*   102.000 2.0
bond_angle O2*  C2*  C3*   114.000 2.0
bond_angle O2*  C2*  C1*   114.000 2.0
bond_angle C1*  C2*  C3*   101.000 2.0
bond_angle O3*  C3*  C4*   112.000 2.0
bond_angle C2*  C3*  O3*   114.000 2.0
! base angles
bond_angle N1   C1*  O4*   108.000 2.0
bond_angle C2   N1   C1*   117.000 2.0
bond_angle C6   N1   C1*   121.000 2.0
bond_angle C5   C6   N1    123.000 2.0
bond_angle C4   C5   C6    119.000 2.0
bond_angle O4   C4   C5    125.000 2.0
bond_angle N3   C4   C5    115.000 2.0
bond_angle C2   N3   C4    127.000 2.0
bond_angle O2   C2   N3    122.000 2.0
bond_angle N1   C2   N3    115.000 2.0
!flexible sugar-phosphate
torsion_flexible O1P  P    O5*  C5*   180.000 20. DUMMY 
torsion_flexible O2P  P    O5*  C5*    60.000 20. DUMMY
torsion_flexible C5*  O5*  P    O3*-  -68.000 20. alpha
torsion_flexible C4*  C5*  O5*  P     178.000 20. beta
torsion_flexible C3*  C4*  C5*  O5*    54.000 20. gamma
!torsion_flexible O3*  C3*  C4*  C5*    82.000 20. delta
torsion_flexible P+   O3*  C3*  C4*  -153.000 20. epsilon
torsion_flexible O5*+ P+   O3*  C3*   -71.000 20. zeta
!sugar-phosphate branches
torsion_fixed    O3*-  P    O5*  O1P   120.000 2.0 branch P
torsion_fixed    O3*-  P    O5*  O2P  -120.000 2.0 branch P
torsion_fixed    C5*   C4*  C3*  O4*  -120.000 2.0 branch C4*
torsion_fixed    O4*   C1*  N1   C2*   120.000 2.0 branch C1*
torsion_fixed    C4*   C3*  O3*  C2*   120.000 2.0 branch C3*
torsion_fixed    C3*   C2*  C1*  O2*  -120.000 2.0 branch C2*
!base torsions, including glycosylic
torsion_flexible C2    N1   C1*  O4*  -158.000 20.  chi
torsion_fixed    C1*   N1   C2   C6    180.000 2.0 branch N1
torsion_fixed    C5    C6   N1   C2      0.000 2.0
torsion_fixed    C4    C5   C6   N1      0.000 2.0
torsion_fixed    C5    C4   N3   O4    180.000 2.0 branch C4
torsion_fixed    N3    C4   C5   C6      0.000 2.0
torsion_fixed    C2    N3   C4   C5      0.000 2.0
torsion_fixed    N3    C2   N1   O2    180.000 2.0 branch C2
torsion_fixed    N1    C2   N3   C4      0.000 2.0
! sugar pucker, flexible (Phil Evans` advice). note Delta is flagged as flexible
torsion_flexible    C1*   C2*  C3*  C4*    37.    2.0 nu2
torsion_flexible    C2*   C3*  C4*  O4*   -36.    2.0 nu3
torsion_flexible    C3*   C4*  O4*  C1*    26.    2.0 nu4
------------------------------------------------------------------------
RESIDUE ADP
centre PA
ATOM   PA O1A O2A O3A PB O1B O2B O3B O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 N3 C4 C5 C6 N6 N7 C8 N9
fragment_all P O1P O2P O5* C5* C4* C3* O3* C2* O2* \
       C1* O4* N1 C2 N3 C4 C5 C6 N6 N7 C8 N9
fragment_mc PA O1A O2A O3A PB O1B O2B O3B O5* C5* C4* C3* O3* C2* O2* C1* O4*
fragment_sc N1 C2 N3 C4 C5 C6 N6 N7 C8 N9
fragment_rsr_1 N1 C2 N3 C4 C5 C6 N6 N7 C8 N9 C1*
fragment_rsr_2 C5* C4* C3* O3* C2* O2* C1* O4* N9
fragment_rsr_3 C4* C5* O5*
fragment_rsr_4 O5* PA O1A O2A O3A
fragment_rsr_5 O3A PB O1B O2B O3B
fragment_rsr_6 PA O3A PB
side-chain N1 C2 N3 C4 C5 C6 N6 N7 C8 N9 O2* C1* O4* C2* O3*
main-chain PA O1A O2A O3A PB O1B O2B O3B  O5* C5* C4* C3*  
CONNECT_ALL O1B PB O3A PA O5* C5* C4* C3* O3* 
CONNECT_ALL C4* O4* C1* C2* C3*
CONNECT_ALL C2* O2*
CONNECT_ALL C1* N9 C4 C5 N7 C8 N9
CONNECT_ALL C4 N3 C2 N1 C6 C5
CONNECT_ALL C6 N6
CONNECT_ALL PA O1A
CONNECT_ALL PA O2A
CONNECT_ALL PB O3B
CONNECT_ALL PB O2B
alpha   O3A P    O5*  C5*
beta    P    O5*  C5*  C4*
gamma   O5*  C5*  C4*  C3*
delta   C5*  C4*  C3*  O3*
chi     O4*  C1*  N9   C4
nu0     C4*  O4*  C1*  C2*
nu1     O4*  C1*  C2*  C3*
nu2     C1*  C2*  C3*  C4*
nu3     C2*  C3*  C4*  O4*
nu4     C3*  C4*  O4*  C1*
rotamer 1 chi -152. nu2  37. nu3 -36 nu4 26.
rotamer 2 chi   28. nu2  37. nu3 -36 nu4 26.
rotamer 3 chi   28. nu2 -34. nu3  24 nu4 -3.
rotamer 4 chi -152. nu2 -34. nu3  24 nu4 -3.
TORSION CHI    O4* C1* N9 C4  N1 C2 N3 C4 C5 C6 N6 N7 C8
TORSION GAMMA  C3* C4* C5* O5* O5* PA O1A O2A O3A PB O1B O2B O3B
TORSION BETA   C4* C5* O5* PA PA O1A O2A O3A PB O1B O2B O3B
TORSION ALPHA  C5* O5* PA O3A O1A O2A O3A PB O1B O2B O3B
TORSION TAU1   O5* PA  O3A PB  PB O1B O2B O3B
TORSION TAU2   PA  O3A  PB O1B O1B O2B O3B
!
! bond lengths
!
bond_distance PB O1B 1.487 0.020
bond_distance PB O3A 1.595 0.020
bond_distance PB O2B 1.502 0.020
bond_distance PB O3B 1.570 0.020
bond_distance PA O1A 1.513 0.020
bond_distance PA O2A 1.507 0.020
bond_distance PA O3A 1.566 0.020
bond_distance PA O5* 1.594 0.020
bond_distance O5* C5* 1.461 0.020
bond_distance C5* C4* 1.536 0.020
bond_distance C4* O4* 1.450 0.020
bond_distance C4* C3* 1.529 0.020
bond_distance O4* C1* 1.422 0.020
bond_distance C3* O3* 1.442 0.020
bond_distance C3* C2* 1.536 0.020
bond_distance C2* O2* 1.432 0.020
bond_distance C2* C1* 1.540 0.020
bond_distance C1* N9 1.502 0.020
bond_distance N9 C8 1.352 0.020
bond_distance N9 C4 1.362 0.020
bond_distance C8 N7 1.344 0.020
bond_distance N7 C5 1.360 0.020
bond_distance C5 C6 1.434 0.020
bond_distance C5 C4 1.384 0.020
bond_distance C6 N6 1.287 0.020
bond_distance C6 N1 1.365 0.020
bond_distance N1 C2 1.376 0.020
bond_distance C2 N3 1.319 0.020
bond_distance N3 C4 1.332 0.020
!
! bond angles
!
bond_angle O1B PB O3A 102.87 2.00
bond_angle O1B PB O2B 113.60 2.00
bond_angle O1B PB O3B 113.99 2.00
bond_angle O2B PB O3B 115.06 2.00
bond_angle O2B PB O3A 103.72 2.00
bond_angle O3B PB O3A 105.87 2.00
bond_angle O1A PA O2A 115.22 2.00
bond_angle O1A PA O3A 108.98 2.00
bond_angle O1A PA O5* 102.96 2.00
bond_angle O2A PA O3A 110.77 2.00
bond_angle O2A PA O5* 114.83 2.00
bond_angle O3A PA O5* 103.13 2.00
bond_angle PB O3A PA 130.33 2.00
bond_angle PA O5* C5* 120.57 2.00
bond_angle O5* C5* C4* 113.90 2.00
bond_angle C5* C4* O4* 109.36 2.00
bond_angle C5* C4* C3* 116.79 2.00
bond_angle O4* C4* C3* 103.28 2.00
bond_angle C4* O4* C1* 111.69 2.00
bond_angle C4* C3* O3* 107.71 2.00
bond_angle C4* C3* C2* 100.96 2.00
bond_angle O3* C3* C2* 115.19 2.00
bond_angle C3* C2* O2* 112.82 2.00
bond_angle C3* C2* C1* 100.84 2.00
bond_angle O2* C2* C1* 106.12 2.00
bond_angle O4* C1* C2* 104.61 2.00
bond_angle O4* C1* N9 108.94 2.00
bond_angle C2* C1* N9 110.92 2.00
bond_angle C1* N9 C8 126.95 2.00
bond_angle C1* N9 C4 126.77 2.00
bond_angle C8 N9 C4 106.25 2.00
bond_angle N9 C8 N7 112.91 2.00
bond_angle C8 N7 C5 103.83 2.00
bond_angle N7 C5 C6 130.63 2.00
bond_angle N7 C5 C4 110.71 2.00
bond_angle C6 C5 C4 118.63 2.00
bond_angle C5 C6 N6 126.45 2.00
bond_angle C5 C6 N1 113.24 2.00
bond_angle N6 C6 N1 120.29 2.00
bond_angle C6 N1 C2 123.32 2.00
bond_angle N1 C2 N3 124.33 2.00
bond_angle C2 N3 C4 113.93 2.00
bond_angle N9 C4 C5 106.26 2.00
bond_angle N9 C4 N3 127.21 2.00
bond_angle C5 C4 N3 126.52 2.00
!
! end phosphate group
torsion_flexible O3B PB O3A PA   180.00 20.00
torsion_fixed    O3B PB O3A O1B  120.00 2.00
torsion_fixed    O3B PB O3A O2B -120.00 2.00
! next phosphate
torsion_flexible PB  O3A PA  O5*  180.00 20.00
torsion_flexible O3A PA  O5* C5*  180.00 20.00
torsion_fixed O3A PA O5* O1A  120.00  2.00
torsion_fixed O3A PA O5* O2A -120.00  2.00
! angles to ring
torsion_flexible PA  O5* C5* C4*  180.00 20.00
torsion_flexible O5* C5* C4* C3*   54.00 20.00 gamma
!sugar-phosphate branches
torsion_fixed    C5*   C4*  C3*  O4*  -120.000 2.0 branch C4*
torsion_fixed    O4*   C1*  N9   C2*   120.000 2.0 branch C1*
torsion_fixed    C4*   C3*  O3*  C2*   120.000 2.0 branch C3*
torsion_fixed    C3*   C2*  C1*  O2*  -120.000 2.0 branch C2*
!base torsions, including glycosylic
torsion_flexible C4    N9   C1*  O4*  -158.000 20.  chi
torsion_fixed    C1*   N9   C4   C8    180.000 2.0 branch N9
torsion_fixed    N7    C8   N9   C4      0.000 2.0
torsion_fixed    C5    N7   C8   N9      0.000 2.0
torsion_fixed    N7    C5   C6   C4    180.000 2.0 branch C5
torsion_fixed    C6    C5   N7   C8    180.000 2.0
torsion_fixed    C5    C6   N1   N6    180.000 2.0 branch C6
torsion_fixed    N1    C6   C5   N7    180.000 2.0
torsion_fixed    C2    N1   C6   C5      0.000 2.0
torsion_fixed    N3    C2   N1   C6      0.000 2.0
torsion_fixed    C4    N3   C2   N1      0.000 2.0
torsion_fixed    N3    C4   N9   C5    180.000 2.0 branch C4
torsion_fixed    N9    C4   N3   C2    180.000 2.0
! sugar pucker, flexible (Phil Evans` advice). note Delta is flagged as flexible
torsion_flexible    C2*   C1*  o4*  C4*   -37.    2.0 nu0
torsion_flexible    C1*   C2*  C3*  C4*    37.    2.0 nu2
torsion_flexible    C2*   C3*  C4*  O4*   -36.    2.0 nu3
torsion_flexible    C3*   C4*  O4*  C1*    26.    2.0 nu4
------------------------------------------------------------------------
residue MSP 
centre CA
ATOM   N     CA    C     O     CB    CG    \
       SD    OE   NE CE PA O1A O2A O3A OT
fragment_all  N     CA    C     O     CB    CG   \
              SD    OE   NE CE PA O1A O2A O3A
fragment_mc N     CA    C     O     CB
fragment_sc CB CG SD    OE   NE CE PA O1A O2A O3A
fragment_rsr_1 CA C O 
fragment_rsr_2 N CA CB C
fragment_rsr_3  CB CG CD
fragment_rsr_4 CG SD    OE   NE CE
fragment_rsr_5 SD NE PA
fragment_rsr_6 NE PA O1A O2A O3A 
side-chain CB CG SD  OE   NE CE PA O1A O2A O3A
main-chain N CA C O CB
chi1  N   CA  CB  CG
chi2  CA  CB  CG  SD
chi3  CB  CG  SD  OE
rotamer Q38% chi1  -60. chi2  180. chi3   0.
rotamer Q20% chi1 -170. chi2  180. chi3   0.
rotamer Q18% chi1  -60. chi2  -60. chi3   0.
rotamer Q10% chi1 -170. chi2   70. chi3   0.
rotamer Q5%  chi1   70. chi2 -170. chi3   0.
TORSION PSI* N CA C O O OT
TORSION CHI1 N CA CB CG CG SD    OE   NE CE PA O1A O2A O3A
TORSION CHI2 CA CB CG SD SD    OE   NE CE PA O1A O2A O3A
TORSION CHI3 CB CG SD NE NE  OE CE PA O1A O2A O3A
TORSION CHI5 SD NE PA O1A O1A O2A O3A
CONNECT_ALL -     N     CA    C     +
CONNECT_ALL CA    CB    CG    SD    NE PA O1A
CONNECT_ALL SD    OE
CONNECT_ALL SD    CE
CONNECT_ALL O2A    PA
CONNECT_ALL O3A    PA
CONNECT_ALL C     O 
CONNECT_ALL C     OT
bond_distance CA   N       1.458 0.02
bond_distance CB   CA      1.530 0.02
bond_distance CG   CB      1.520 0.02
bond_distance C    CA      1.525 0.02
bond_distance O    C       1.231 0.02
bond_angle CB   CA   N     110.500 2.0
bond_angle CG   CB   CA    114.100 2.0
bond_angle C    CA   N     111.200 2.0
bond_angle C    CA   CB    110.200 2.0
bond_angle O    C    CA    120.800 2.0
torsion_flexible N CA C O 180. 2.
!side-chain torsions
torsion_flexible CG   CB   CA   N     -60.000 20.
!main-chain torsions
torsion_fixed    N    CA   C    CB   -123.000 2.0

bond_distance SD   CG      1.80 0.02
bond_angle SD   CG   CB    114.0 2.0
torsion_flexible SD   CG   CB   CA    180.000 20.

bond_distance NE   SD      1.54 0.02
bond_angle NE   SD   CG    110.5 2.0
torsion_flexible NE   SD   CG   CB      180.000 20.
bond_distance OE   SD      1.46 0.02
bond_angle OE   SD   CG    106.8 2.0
torsion_fixed    CG   SD   NE   OE   120.000 2.0

bond_distance CE   SD      1.76 0.02
bond_angle CE   SD   CG    105. 2.0
torsion_fixed    CG   SD   NE   CE   -120.000 2.0

bond_angle NE   SD   OE   120. 2.0
bond_angle NE   SD   CE   104. 2.0
bond_angle CE   SD   OE   110. 2.0

bond_distance NE PA 1.6 .02
bond_angle PA NE SD  120. 2.0
torsion_fixed PA NE SD CG 180. 2.

bond_distance PA O1A 1.5 .02
bond_angle O1A PA NE 112. 2.
torsion_flexible O1A PA NE SD 180. 20.

bond_distance PA O2A 1.5 .02
bond_angle O2A PA NE 112. 2.
torsion_fixed NE PA O1A O2A 120. 20.
bond_distance PA O3A 1.5 .02
bond_angle O3A PA NE 112. 2.
torsion_fixed NE PA O1A O3A -120. 20.
bond_angle O3A PA O1A 112. 2.
bond_angle O2A PA O1A 112. 2.
bond_angle O3A PA O2A 112. 2.


bond_distance OT    C       1.231 0.02
bond_angle OT    C    CA    120.800 2.0
torsion_fixed CA C O OT 180. 2.
------------------------------------------------------------------------
! these are from Phil Evan`s Nucleic Acid torsion dictionary, but `->*
RESIDUE T
TORSION ALPH  O3*- P O5* C5* C5* C4* O4* C1* C2* C3* O3* N1 C2 N3 \
              C4 C5 C6 O2 O4 C5A
TORSION BETA  P O5* C5* C4* C4* O4* C1* C2* C3* O3* N1 C2 N3 \
              C4 C5 C6 O2 O4 C5A
TORSION GAMM  O5* C5* C4* C3* O4* C1* C2* C3* O3* N1 C2 N3 \
              C4 C5 C6 O2 O4 C5A
TORSION DELT  C5* C4* C3* O3* O4* C1* C2* O3* N1 C2 N3 \
              C4 C5 C6 O2 O4 C5A
TORSION EPSI  C4* C3* O3* P+
TORSION ZETA  C3* O3* P+ O5*+
TORSION CHI   O4* C1* N1 C2 N1 C2 N3 \
              C4 C5 C6 O2 O4 C5A
RESIDUE ADE
TORSION ALP  O4* C1* N9 C8 C8 C4 C5 N7 N3 C2 N1 C6 N6
TORSION BET  C8 N9 C1* O4* O4* C4* C3* O3* C2* O2* C5* O5* P \
             O1P O2P
TORSION GAM  O4* C4* C5* O5* O5* P O1P O2P
TORSION DEL  C4* C5* O5* P P O1P O2P
TORSION EPS  C5* O5* P O1P O1P O2P
TORSION KAP  O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N9 C8 \
             C4 C5 N7 N3 C2 N1 C6 N6
RESIDUE GUA
TORSION ALP  O4* C1* N9 C8 C8 C4 C5 N7 N3 C2 N1 C6 O6 N2
TORSION BET  C8 N9 C1* O4* O4* C4* C3* O3* C2* O2* C5* O5* P \
             O1P O2P
TORSION GAM  O4* C4* C5* O5* O5* P O1P O2P
TORSION DEL  C4* C5* O5* P P O1P O2P
TORSION EPS  C5* O5* P O1P O1P O2P
TORSION KAP  O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N9 C8 \
             C4 C5 N7 N3 C2 N1 C6 O6 N2
RESIDUE CYT
TORSION ALP  C2* C1* N1 C6 C5 C4 N4 N3 C2 O2 C6
TORSION BET  C6 N1 C1* O4* O4* C2* O2* C3* O3* C4* C5* O5* \
             P O1P O2P
TORSION GAM  O4* C4* C5* O5* O5* P O1P O2P
TORSION DEL  C4* C5* O5* P P O1P O2P
TORSION EPS  C5* O5* P O1P O1P O2P
TORSION KAP  O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N1 C6 \
             C5 C4 N4 N3 C2 O2
RESIDUE URA
TORSION ALP  C2* C1* N1 C6 C5 C4 O4 N3 C2 O2 C6
TORSION BET  C6 N1 C1* O4* O4* C2* O2* C3* O3* C4* C5* O5* \
             P O1P O2P
TORSION GAM  O4* C4* C5* O5* O5* P O1P O2P
TORSION DEL  C4* C5* O5* P P O1P O2P
TORSION EPS  C5* O5* P O1P O1P O2P
TORSION KAP  O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* N1 C6 \
             C5 C4 O4 N3 C2 O2
RESIDUE THY
TORSION ALP  C2* C1* N1 C2 N3 C4 C5 C6 O2 O4 C5A
TORSION BET  C6 N1 C1* O4* O4* C2* O2* C3* O3* C4* C5* O5* \
             P O1P O2P
TORSION GAM  O4* C4* C5* O5* O5* P O1P O2P
TORSION DEL  C4* C5* O5* P P O1P O2P
TORSION EPS  C5* O5* P O1P O1P O2P
TORSION KAP  O5* C5* C4* C3* C3* O3* C2* O2* C1* O4* \
             N1 C2 N3 C4 C5 C6 O2 O4 C5A
RESIDUE ATP
TORSION CHI  O4* C1* N9 C4  N1 C2 N3 C4 C5 C6 N6 N7 C8
TORSION GAMMA C3* C4* C5* O5* O5* P1 O11 O12 O6 P2 O21 O22 O7 P3 \
              O31 O32 O8
TORSION BETA   C4* C5* O5* P1 P1 O11 O12 O6 P2 O21 O22 O7 P3 O31 O32 O8
TORSION ALPHA  C5* O5* P1 O6 O11 O12 O6 P2 O21 O22 O7 P3 O31 O32 O8
TORSION TAU1   O5* P1  O6 P2  P2 O21 O22 O7 P3 O31 O32 O8
TORSION TAU2   P1  O6  P2 O7 O21 O22 O7 P3 O31 O32 O8
TORSION TAU3   O6  P2  O7 P3 P3 O31 O32 O8
TORSION TAU4   P2  O7  P3 O8 O31 O32 O8

RESIDUE COA
TORSION CHI    O4* C1* N9 C4  N1 C2 N3 C4 C5 C6 N6 N7 C8
TORSION PHI*   C2* C3* O3* P3    P3 O31 O32 O33
TORSION OMEGA* C3* O3* P3  O31   O31 O32 O33
TORSION PSI    C3* C4* C5* O5* \
             O5* P1 O11 O12 O6 P2 O21 O22 O7 CPB  CPA CP8 CP9 CP7 OP3 \
             CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION PHI    C4* C5* O5* P1 \
               P1 O11 O12 O6 P2 O21 O22 O7 CPB  CPA CP8 CP9 CP7 OP3 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION OMEGA  C5* O5* P1 O6 \
               O6  O11 O12 O6 P2 O21 O22 O7 CPB  CPA CP8 CP9 CP7 OP3 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU1   O5* P1 O6 P2 \
               P2  O21 O22 O7 CPB  CPA CP8 CP9 CP7 OP3 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU2   P1 O6 P2 O7 \
               O7 CPB  CPA CP8 CP9 CP7 OP3 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU3   O6 P2 O7 CPB \
               CPB CPA CP8 CP9 CP7 OP3 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU4   P2 O7 CPB CPA \
               CPA CP8 CP9 CP7 OP3 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU5   O7 CPB CPA CP7 \
               CP7 OP3 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU6   CPB CPA CP7 CP6 \
               CP6 OP2 NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU7   CPA CP7 CP6 NP2 \
               NP2 CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU8   CP7 CP6 NP2 CP5 \
               CP5 CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU9   CP6 NP2 CP5 CP4    CP4 CP3 OP1 NP1 CP2 CP1 S
TORSION TAU10  NP2 CP5 CP4 CP3    CP3 OP1 NP1 CP2 CP1 S
TORSION TAU11  CP5 CP4 CP3 NP1    NP1 CP2 CP1 S
TORSION TAU12  CP4 CP3 NP1 CP2    CP2 CP1 S
TORSION TAU13  CP3 NP1 CP2 CP1    CP1 S
TORSION TAU14  NP1 CP2 CP1 S       S
RESIDUE B12
TORSION TAU31  C6  C7  C37 C38    C38 O39 N40
TORSION TAU32  C7  C37 C38 O39    O39 N40
TORSION TAU41  C7  C8  C41 C42    C42 C43 O44 N45
TORSION TAU42  C8  C41 C42 C43    C43 O44 N45
TORSION TAU43  C41 C42 C43 O44    O44 N45
TORSION TAU51  C12 C13 C48 C49    C49 C50 O51 N52
TORSION TAU52  C13 C48 C49 C50    C50 O51 N52
TORSION TAU53  C48 C49 C50 O51    O51 N52
TORSION TAU61  C17 C18 C60 C61    C61 O63 N62
TORSION TAU62  C18 C60 C61 O63    O63 N62
RESIDUE MCD
TORSION TAU1  CP4 NP1 CP2 CP1  CP1 CPS CS1 OS1 CS2 CS3 CS4 OS4 OS5
TORSION TAU2  NP1 CP2 CP1 CPS  CPS CS1 OS1 CS2 CS3 CS4 OS4 OS5
TORSION TAU3  CP2 CP1 CPS CS1  CS1 OS1 CS2 CS3 CS4 OS4 OS5
TORSION TAU4  CP1 CPS CS1 CS2  OS1 CS2 CS3 CS4 OS4 OS5
TORSION TAU5  CPS CS1 CS2 CS4  CS3 CS4 OS4 OS5
TORSION TAU6  CS1 CS2 CS4 OS4  OS4 OS5
RESIDUE ADD
TORSION CHI   C4 N9 C1* C2*  C2* O2* C3* O3* C4* O4* C5*
TORSION CHIB  C2* C1* N9 C8  C8 C4 C5 N7 N3 C2 N1 C6 N6
RESIDUE GOL
TORSION TAU1  C3  C2  C1  O1   O1
TORSION TAU2  C1  C2  C3  O3   O3
!read ok : here is grab_fragment definition for ADP too
RSR_DICT_ADP T 3 70
PA O1A O2A O3A PB O1B O2B O3B O5* 
C5* C4* C3* O3* C2* O2* C1* O4* 
N1 C2 N3 C4 C5 C6 N6 N7 C8 N9' > stereochem_duke10.odb

echo '! O rotamer file of the Richardson Lab (Duke) library. Reference
! SC Lovell, JM Word, JS Richardson & DC Richardson, 2000 Proteins 40:389-408
! Questions and comments to: arendall@duke.edu or dcr@kinemage.biochem.duke.edu
SCALA_ATOM_XYZ            R         15 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.540   0.001   1.438
SCALA_ATOM_B              R          5 (10(x,f7.4))
  0.0000  0.0000  0.0000  0.0000  0.0000
SCALA_RESIDUE_NAME        C          1 (1x,5a)
 Z1   
SCALA_RESIDUE_TYPE        C          1 (1x,5a)
 ALA  
SCALA_ATOM_NAME           C          5 (1x,5a)
 C     N     O     CA    CB   
SCALA_RESIDUE_POINTERS    I          2 (20(x,i3))
   1   5
SCALA_RESIDUE_CG          R          4 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
SCALA_ATOMS_IN_RESIDUES   C          5 (1x,5a)
 C     N     O     CA    CB   
SCARG_ATOM_XYZ            R        924 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.805   1.209   3.616   0.534   2.428
   4.371   0.246   1.277   2.204   1.584   1.684   6.277   0.624   3.770   6.236
   0.915   2.628   5.629   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024
  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.805   1.209
   3.616   0.534   2.428   4.371   0.246   1.277   2.204   2.378   3.540   3.565
   0.970   4.581   5.052   1.295   3.517   4.329   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.805   1.209   3.616   0.534   2.428   4.371   0.246   1.277   2.204
  -1.560   1.755   5.038  -0.749   3.801   5.695  -0.593   2.662   5.035   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   0.805   1.209   3.616   0.148   0.179   4.415
   0.246   1.277   2.204   1.529   0.465   6.231  -0.147  -1.104   6.300   0.510
  -0.153   5.650   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   1.062   1.347   3.484
   0.692   0.295   4.427   0.246   1.277   2.204  -1.054   1.485   5.333  -0.575
  -0.622   6.111  -0.313   0.387   5.291   0.551  -1.198  -0.766  -1.458   0.000
   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433
   0.805   1.209   3.616   0.148   0.179   4.415   0.246   1.277   2.204   1.920
  -1.281   4.303   0.024  -1.866   5.459   0.698  -0.990   4.726   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.805   1.209   3.616   2.263   1.137   3.624   0.246
   1.277   2.204   2.407   0.863   5.902   4.319   0.920   4.630   2.997   0.974
   4.720   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   0.805   1.209   3.616   2.263
   1.137   3.624   0.246   1.277   2.204   2.321  -1.099   4.153   4.281   0.063
   3.866   2.955   0.033   3.881   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.805
   1.209   3.616   2.263   1.137   3.624   0.246   1.277   2.204   2.546   3.415
   3.492   4.379   2.034   3.578   3.063   2.197   3.564   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433   0.822   2.477   1.712   0.455   3.665   2.478   0.143   1.225
   2.242   1.749   5.087   1.218   0.520   5.908   2.975   0.909   4.888   2.223
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.822   2.477   1.712   0.455   3.665
   2.478   0.143   1.225   2.242  -1.469   4.053   1.281  -0.885   5.457   3.003
  -0.634   4.392   2.254   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024
  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.822   2.477
   1.712   2.272   2.423   1.870   0.143   1.225   2.242   2.640   4.396   0.749
   4.415   3.210   1.597   3.110   3.344   1.405   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.822   2.477   1.712   2.272   2.423   1.870   0.143   1.225   2.242
   2.237   3.210   4.030   4.239   2.692   3.030   2.916   2.775   2.978   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   2.575   1.394   0.990   2.134   2.528   1.797
   2.051   0.073   1.529   3.847   2.329   3.318   2.280   3.991   3.564   2.754
   2.949   2.894   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.575   1.394   0.990
   4.030   1.481   1.074   2.051   0.073   1.529   4.382   0.388  -0.918   6.172
   1.123   0.319   4.862   0.997   0.157   0.551  -1.198  -0.766  -1.458   0.000
   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433
   2.575   1.394   0.990   4.030   1.481   1.074   2.051   0.073   1.529   4.129
   3.585   0.153   6.061   2.518   0.787   4.741   2.529   0.671   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.513   0.069   2.977   2.196  -1.188   3.649   2.051
   0.073   1.529   4.092  -2.259   2.914   2.589  -3.372   4.247   2.960  -2.274
   3.603   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   2.513   0.069   2.977   2.196
  -1.188   3.649   2.051   0.073   1.529   2.932  -0.471   5.706   2.083  -2.592
   5.466   2.404  -1.417   4.941   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.513
   0.069   2.977   3.968   0.138   3.087   2.051   0.073   1.529   4.040   2.431
   2.943   5.986   1.234   3.175   4.665   1.269   3.068   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433   2.513   0.069   2.977   3.968   0.138   3.087   2.051   0.073
   1.529   3.966   0.096   5.386   5.954   0.214   4.242   4.629   0.149   4.239
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.513   0.069   2.977   3.968   0.138
   3.087   2.051   0.073   1.529   4.264  -2.130   2.859   6.084  -0.758   3.139
   4.772  -0.918   3.028   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024
  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.513   0.069
   2.977   2.075   1.263   3.694   2.051   0.073   1.529   0.427   0.164   4.862
   0.757   2.414   5.184   1.086   1.280   4.581   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   2.513   0.069   2.977   2.075   1.263   3.694   2.051   0.073   1.529
   2.882   0.546   5.724   1.829   2.581   5.561   2.262   1.463   4.994   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   2.513   0.069   2.977   2.075   1.263   3.694
   2.051   0.073   1.529   3.857   2.540   3.002   2.255   3.452   4.372   2.729
   2.419   3.689   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.708  -1.159   3.652
   0.138  -0.055   4.419   0.143  -1.225   2.242   1.493  -0.398   6.244  -0.049
   1.304   6.263   0.528   0.284   5.643   0.551  -1.198  -0.766  -1.458   0.000
   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433
   0.708  -1.159   3.652   0.340  -2.329   4.444   0.143  -1.225   2.242   2.085
  -3.612   3.674   0.599  -4.488   5.190   1.009  -3.477   4.436   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.708  -1.159   3.652   0.340  -2.329   4.444   0.143
  -1.225   2.242   1.449  -1.616   6.327   0.322  -3.616   6.349   0.704  -2.521
   5.708   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   0.708  -1.159   3.652   0.340
  -2.329   4.444   0.143  -1.225   2.242  -1.692  -1.468   5.087  -1.050  -3.552
   5.807  -0.802  -2.450   5.113
SCARG_ATOM_B              R        308 (10(x,f7.4))
  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000
  9.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000
  6.0000  6.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000
  4.0000  4.0000  4.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000
  5.0000  5.0000  5.0000  5.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000
  6.0000  6.0000  6.0000  6.0000  6.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  5.0000  5.0000  5.0000  5.0000
  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  1.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  4.0000  4.0000  4.0000  4.0000
  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  4.0000
  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000
  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  1.0000  1.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
SCARG_RESIDUE_NAME        C         28 (1x,5a)
 Z2    Z3    Z4    Z5    Z6   
 Z7    Z8    Z9    Z10   Z11  
 Z12   Z13   Z14   Z15   Z16  
 Z17   Z18   Z19   Z20   Z21  
 Z22   Z23   Z24   Z25   Z26  
 Z27   Z28   Z29  
SCARG_RESIDUE_TYPE        C         28 (1x,5a)
 ARG   ARG   ARG   ARG   ARG  
 ARG   ARG   ARG   ARG   ARG  
 ARG   ARG   ARG   ARG   ARG  
 ARG   ARG   ARG   ARG   ARG  
 ARG   ARG   ARG   ARG   ARG  
 ARG   ARG   ARG  
SCARG_ATOM_NAME           C        308 (1x,5a)
 C     N     O     CA    CB   
 CD    NE    CG    NH1   NH2  
 CZ    C     N     O     CA   
 CB    CD    NE    CG    NH1  
 NH2   CZ    C     N     O    
 CA    CB    CD    NE    CG   
 NH1   NH2   CZ    C     N    
 O     CA    CB    CD    NE   
 CG    NH1   NH2   CZ    C    
 N     O     CA    CB    CD   
 NE    CG    NH1   NH2   CZ   
 C     N     O     CA    CB   
 CD    NE    CG    NH1   NH2  
 CZ    C     N     O     CA   
 CB    CD    NE    CG    NH1  
 NH2   CZ    C     N     O    
 CA    CB    CD    NE    CG   
 NH1   NH2   CZ    C     N    
 O     CA    CB    CD    NE   
 CG    NH1   NH2   CZ    C    
 N     O     CA    CB    CD   
 NE    CG    NH1   NH2   CZ   
 C     N     O     CA    CB   
 CD    NE    CG    NH1   NH2  
 CZ    C     N     O     CA   
 CB    CD    NE    CG    NH1  
 NH2   CZ    C     N     O    
 CA    CB    CD    NE    CG   
 NH1   NH2   CZ    C     N    
 O     CA    CB    CD    NE   
 CG    NH1   NH2   CZ    C    
 N     O     CA    CB    CD   
 NE    CG    NH1   NH2   CZ   
 C     N     O     CA    CB   
 CD    NE    CG    NH1   NH2  
 CZ    C     N     O     CA   
 CB    CD    NE    CG    NH1  
 NH2   CZ    C     N     O    
 CA    CB    CD    NE    CG   
 NH1   NH2   CZ    C     N    
 O     CA    CB    CD    NE   
 CG    NH1   NH2   CZ    C    
 N     O     CA    CB    CD   
 NE    CG    NH1   NH2   CZ   
 C     N     O     CA    CB   
 CD    NE    CG    NH1   NH2  
 CZ    C     N     O     CA   
 CB    CD    NE    CG    NH1  
 NH2   CZ    C     N     O    
 CA    CB    CD    NE    CG   
 NH1   NH2   CZ    C     N    
 O     CA    CB    CD    NE   
 CG    NH1   NH2   CZ    C    
 N     O     CA    CB    CD   
 NE    CG    NH1   NH2   CZ   
 C     N     O     CA    CB   
 CD    NE    CG    NH1   NH2  
 CZ    C     N     O     CA   
 CB    CD    NE    CG    NH1  
 NH2   CZ    C     N     O    
 CA    CB    CD    NE    CG   
 NH1   NH2   CZ   
SCARG_RESIDUE_POINTERS    I         56 (20(x,i3))
   1  11  12  22  23  33  34  44  45  55  56  66  67  77  78  88  89  99 100 110
 111 121 122 132 133 143 144 154 155 165 166 176 177 187 188 198 199 209 210 220
 221 231 232 242 243 253 254 264 265 275 276 286 287 297 298 308
SCARG_RESIDUE_CG          R        112 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCARG_ATOMS_IN_RESIDUES   C         11 (1x,5a)
 C     N     O     CA    CB   
 CD    NE    CG    NH1   NH2  
 CZ   
SCASN_ATOM_XYZ            R        216 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.216   1.195   3.511  -0.108   2.299
   1.582   0.186   1.268   2.186   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433  -0.792
   1.175   3.077   0.789   2.318   1.966   0.186   1.268   2.186   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.659   2.402   1.684  -0.499   1.226   3.207   0.186
   1.268   2.186   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.509   1.363   1.742
   2.778  -0.825   1.311   2.044   0.146   1.491   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   2.550   0.583   2.638   2.741  -0.129   0.516   2.044   0.146   1.491
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.629  -0.494   2.540   2.686   0.635
   0.599   2.049   0.073   1.489   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   1.097
  -1.897   2.825  -1.053  -1.590   2.252   0.125  -1.235   2.209   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.727  -1.427   3.376  -0.723  -2.007   1.762   0.125
  -1.235   2.209   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.001  -1.093   3.523
  -0.077  -2.303   1.632   0.125  -1.235   2.209
SCASN_ATOM_B              R         72 (10(x,f7.4))
 39.0000 39.0000 39.0000 39.0000 39.0000 39.0000 39.0000 39.0000  8.0000  8.0000
  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000  4.0000  4.0000  4.0000  4.0000
  4.0000  4.0000  4.0000  4.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000 12.0000 12.0000 12.0000 12.0000 12.0000 12.0000 12.0000 12.0000
 15.0000 15.0000 15.0000 15.0000 15.0000 15.0000 15.0000 15.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  7.0000  7.0000  7.0000  7.0000
  7.0000  7.0000  7.0000  7.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000
  9.0000  9.0000
SCASN_RESIDUE_NAME        C          9 (1x,5a)
 Z30   Z31   Z32   Z33   Z34  
 Z35   Z36   Z37   Z38  
SCASN_RESIDUE_TYPE        C          9 (1x,5a)
 ASN   ASN   ASN   ASN   ASN  
 ASN   ASN   ASN   ASN  
SCASN_ATOM_NAME           C         72 (1x,5a)
 C     N     O     CA    CB   
 ND2   OD1   CG    C     N    
 O     CA    CB    ND2   OD1  
 CG    C     N     O     CA   
 CB    ND2   OD1   CG    C    
 N     O     CA    CB    ND2  
 OD1   CG    C     N     O    
 CA    CB    ND2   OD1   CG   
 C     N     O     CA    CB   
 ND2   OD1   CG    C     N    
 O     CA    CB    ND2   OD1  
 CG    C     N     O     CA   
 CB    ND2   OD1   CG    C    
 N     O     CA    CB    ND2  
 OD1   CG   
SCASN_RESIDUE_POINTERS    I         18 (20(x,i3))
   1   8   9  16  17  24  25  32  33  40  41  48  49  56  57  64  65  72
SCASN_RESIDUE_CG          R         36 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCASN_ATOMS_IN_RESIDUES   C          8 (1x,5a)
 C     N     O     CA    CB   
 ND2   OD1   CG   
SCASP_ATOM_XYZ            R        192 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433  -0.027   2.312   1.464   0.419   1.350
   3.388   0.292   1.315   2.147   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.596
   2.359   1.735  -0.498   1.172   3.226   0.186   1.268   2.186   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.736  -0.139   0.538   2.498   0.816   2.502   2.031
   0.243   1.496   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.682   0.124   0.414
   2.602   0.081   2.609   2.049   0.073   1.489   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   2.611   1.106   1.066   2.674  -0.901   1.958   2.049   0.073   1.489
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433  -1.080  -1.565   2.208   1.007  -1.876
   2.818   0.125  -1.235   2.209   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433  -0.727
  -1.998   1.705   0.655  -1.443   3.321   0.125  -1.235   2.209   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433  -0.051  -2.301   1.581  -0.021  -1.139   3.446   0.125
  -1.235   2.209
SCASP_ATOM_B              R         64 (10(x,f7.4))
 51.0000 51.0000 51.0000 51.0000 51.0000 51.0000 51.0000 51.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000 21.0000 21.0000 21.0000 21.0000 21.0000 21.0000
 21.0000 21.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000 10.0000 10.0000
 10.0000 10.0000 10.0000 10.0000 10.0000 10.0000  9.0000  9.0000  9.0000  9.0000
  9.0000  9.0000  9.0000  9.0000
SCASP_RESIDUE_NAME        C          8 (1x,5a)
 Z39   Z40   Z41   Z42   Z43  
 Z44   Z45   Z46  
SCASP_RESIDUE_TYPE        C          8 (1x,5a)
 ASP   ASP   ASP   ASP   ASP  
 ASP   ASP   ASP  
SCASP_ATOM_NAME           C         64 (1x,5a)
 C     N     O     CA    CB   
 OD1   OD2   CG    C     N    
 O     CA    CB    OD1   OD2  
 CG    C     N     O     CA   
 CB    OD1   OD2   CG    C    
 N     O     CA    CB    OD1  
 OD2   CG    C     N     O    
 CA    CB    OD1   OD2   CG   
 C     N     O     CA    CB   
 OD1   OD2   CG    C     N    
 O     CA    CB    OD1   OD2  
 CG    C     N     O     CA   
 CB    OD1   OD2   CG   
SCASP_RESIDUE_POINTERS    I         16 (20(x,i3))
   1   8   9  16  17  24  25  32  33  40  41  48  49  56  57  64
SCASP_RESIDUE_CG          R         32 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCASP_ATOMS_IN_RESIDUES   C          8 (1x,5a)
 C     N     O     CA    CB   
 OD1   OD2   CG   
SCCYH_ATOM_XYZ            R         54 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.143   1.504   2.384   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.352   0.087   1.558   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.070  -1.465   2.411
SCCYH_ATOM_B              R         18 (10(x,f7.4))
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
SCCYH_RESIDUE_NAME        C          3 (1x,5a)
 A47   A48   A49  
SCCYH_RESIDUE_TYPE        C          3 (1x,5a)
 CYH   CYH   CYH  
SCCYH_ATOM_NAME           C         18 (1x,5a)
 C     N     O     CA    CB   
 SG    C     N     O     CA   
 CB    SG    C     N     O    
 CA    CB    SG   
SCCYH_RESIDUE_POINTERS    I          6 (20(x,i3))
   1   6   7  12  13  18
SCCYH_RESIDUE_CG          R         12 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCCYH_ATOMS_IN_RESIDUES   C          6 (1x,5a)
 C     N     O     CA    CB   
 SG   
SCCYS_ATOM_XYZ            R         54 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.143   1.504   2.384   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.352   0.087   1.558   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.070  -1.465   2.411
SCCYS_ATOM_B              R         18 (10(x,f7.4))
 50.0000 50.0000 50.0000 50.0000 50.0000 50.0000 23.0000 23.0000 23.0000 23.0000
 23.0000 23.0000 26.0000 26.0000 26.0000 26.0000 26.0000 26.0000
SCCYS_RESIDUE_NAME        C          3 (1x,5a)
 Z47   Z48   Z49  
SCCYS_RESIDUE_TYPE        C          3 (1x,5a)
 CYS   CYS   CYS  
SCCYS_ATOM_NAME           C         18 (1x,5a)
 C     N     O     CA    CB   
 SG    C     N     O     CA   
 CB    SG    C     N     O    
 CA    CB    SG   
SCCYS_RESIDUE_POINTERS    I          6 (20(x,i3))
   1   6   7  12  13  18
SCCYS_RESIDUE_CG          R         12 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCCYS_ATOMS_IN_RESIDUES   C          6 (1x,5a)
 C     N     O     CA    CB   
 SG   
SCGLN_ATOM_XYZ            R        405 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.791   1.240   3.618   1.055   2.415
   4.180   0.973   0.169   4.196   0.246   1.278   2.204   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433  -1.166   1.196   2.866  -1.531   2.258   3.575  -1.883   0.206
   2.730   0.205   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.791
   1.240   3.618   1.681   2.175   3.932   0.416   0.382   4.416   0.246   1.278
   2.204   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   0.791   1.240   3.618  -0.098
   1.374   4.596   1.995   1.096   3.826   0.246   1.278   2.204   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.871   2.494   1.648   0.140   3.603   1.629   2.027
   2.450   1.228   0.205   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000
   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433
   0.871   2.494   1.648   2.147   2.677   1.966   0.244   3.274   0.932   0.205
   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.607   1.379   0.997
   2.539   2.424   1.814   3.088   1.446  -0.133   2.051   0.072   1.529   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   2.607   1.379   0.997   3.455   1.289  -0.021
   2.277   2.454   1.498   2.051   0.072   1.529   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   2.545   0.071   2.962   3.347  -0.929   3.309   2.207   0.957   3.746
   2.051   0.072   1.529   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024
  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.545   0.071
   2.962   3.861   0.130   3.133   1.752   0.016   3.902   2.051   0.072   1.529
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.545   0.071   2.962   3.250   1.129
   3.344   2.295  -0.871   3.714   2.051   0.072   1.529   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433   0.692  -1.190   3.655  -0.203  -1.215   4.637   1.905  -1.140
   3.859   0.143  -1.225   2.243   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.692
  -1.190   3.655   0.758  -2.354   4.291   1.050  -0.130   4.167   0.143  -1.225
   2.243   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   0.692  -1.190   3.655   1.499
  -2.187   3.999   0.392  -0.279   4.426   0.143  -1.225   2.243   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433  -1.132  -1.479   2.621  -1.416  -2.596   3.280  -1.977
  -0.620   2.369   0.308  -1.304   2.181
SCGLN_ATOM_B              R        135 (10(x,f7.4))
 35.0000 35.0000 35.0000 35.0000 35.0000 35.0000 35.0000 35.0000 35.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000 15.0000 15.0000 15.0000 15.0000
 15.0000 15.0000 15.0000 15.0000 15.0000  3.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000
  9.0000  9.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  4.0000  4.0000
  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000
SCGLN_RESIDUE_NAME        C         15 (1x,5a)
 Z50   Z51   Z52   Z53   Z54  
 Z55   Z56   Z57   Z58   Z59  
 Z60   Z61   Z62   Z63   Z64  
SCGLN_RESIDUE_TYPE        C         15 (1x,5a)
 GLN   GLN   GLN   GLN   GLN  
 GLN   GLN   GLN   GLN   GLN  
 GLN   GLN   GLN   GLN   GLN  
SCGLN_ATOM_NAME           C        135 (1x,5a)
 C     N     O     CA    CB   
 CD    NE2   OE1   CG    C    
 N     O     CA    CB    CD   
 NE2   OE1   CG    C     N    
 O     CA    CB    CD    NE2  
 OE1   CG    C     N     O    
 CA    CB    CD    NE2   OE1  
 CG    C     N     O     CA   
 CB    CD    NE2   OE1   CG   
 C     N     O     CA    CB   
 CD    NE2   OE1   CG    C    
 N     O     CA    CB    CD   
 NE2   OE1   CG    C     N    
 O     CA    CB    CD    NE2  
 OE1   CG    C     N     O    
 CA    CB    CD    NE2   OE1  
 CG    C     N     O     CA   
 CB    CD    NE2   OE1   CG   
 C     N     O     CA    CB   
 CD    NE2   OE1   CG    C    
 N     O     CA    CB    CD   
 NE2   OE1   CG    C     N    
 O     CA    CB    CD    NE2  
 OE1   CG    C     N     O    
 CA    CB    CD    NE2   OE1  
 CG    C     N     O     CA   
 CB    CD    NE2   OE1   CG   
SCGLN_RESIDUE_POINTERS    I         30 (20(x,i3))
   1   9  10  18  19  27  28  36  37  45  46  54  55  63  64  72  73  81  82  90
  91  99 100 108 109 117 118 126 127 135
SCGLN_RESIDUE_CG          R         60 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCGLN_ATOMS_IN_RESIDUES   C          9 (1x,5a)
 C     N     O     CA    CB   
 CD    NE2   OE1   CG   
SCGLU_ATOM_XYZ            R        405 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.791   1.240   3.618   1.225   0.156
   4.060   0.785   2.297   4.285   0.246   1.278   2.204   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433  -1.166   1.196   2.866  -1.856   0.169   2.698  -1.548   2.175
   3.541   0.205   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.791
   1.240   3.618   0.379   0.350   4.391   1.631   2.102   3.954   0.246   1.278
   2.204   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   0.791   1.240   3.618   2.020
   1.091   3.778  -0.012   1.362   4.568   0.246   1.278   2.204   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.871   2.494   1.648   2.045   2.399   1.235   0.217
   3.558   1.612   0.205   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000
   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433
   1.052   2.445   1.804   1.899   2.283   0.900   0.868   3.537   2.381   0.205
   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.607   1.379   0.997
   1.807   2.300   0.731   3.843   1.482   0.848   2.051   0.072   1.529   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   2.545   0.071   2.962   2.174   0.992   3.719
   3.302  -0.853   3.329   2.051   0.072   1.529   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   2.545   0.071   2.962   1.701   0.014   3.881   3.776   0.126   3.167
   2.051   0.072   1.529   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024
  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.545   0.071
   2.962   2.266  -0.908   3.686   3.212   1.049   3.362   2.051   0.072   1.529
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.714  -1.272   1.298   2.055  -2.307
   1.532   3.892  -1.291   0.883   2.051   0.072   1.529   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433   0.692  -1.190   3.655   1.930  -1.139   3.811  -0.116  -1.212
   4.608   0.143  -1.225   2.243   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.692
  -1.190   3.655   1.663  -0.443   3.897   0.151  -1.910   4.521   0.143  -1.225
   2.243   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   0.692  -1.190   3.655   0.358
  -0.245   4.400   1.456  -2.110   4.019   0.143  -1.225   2.243   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433  -1.102  -1.424   2.726  -1.901  -0.487   2.518  -1.408
  -2.456   3.359   0.308  -1.304   2.181
SCGLU_ATOM_B              R        135 (10(x,f7.4))
 33.0000 33.0000 33.0000 33.0000 33.0000 33.0000 33.0000 33.0000 33.0000  6.0000
  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000 13.0000 13.0000 13.0000 13.0000
 13.0000 13.0000 13.0000 13.0000 13.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000
  6.0000  6.0000  6.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  5.0000  5.0000
  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000
SCGLU_RESIDUE_NAME        C         15 (1x,5a)
 Z65   Z66   Z67   Z68   Z69  
 Z70   Z71   Z72   Z73   Z74  
 Z75   Z76   Z77   Z78   Z79  
SCGLU_RESIDUE_TYPE        C         15 (1x,5a)
 GLU   GLU   GLU   GLU   GLU  
 GLU   GLU   GLU   GLU   GLU  
 GLU   GLU   GLU   GLU   GLU  
SCGLU_ATOM_NAME           C        135 (1x,5a)
 C     N     O     CA    CB   
 CD    OE1   OE2   CG    C    
 N     O     CA    CB    CD   
 OE1   OE2   CG    C     N    
 O     CA    CB    CD    OE1  
 OE2   CG    C     N     O    
 CA    CB    CD    OE1   OE2  
 CG    C     N     O     CA   
 CB    CD    OE1   OE2   CG   
 C     N     O     CA    CB   
 CD    OE1   OE2   CG    C    
 N     O     CA    CB    CD   
 OE1   OE2   CG    C     N    
 O     CA    CB    CD    OE1  
 OE2   CG    C     N     O    
 CA    CB    CD    OE1   OE2  
 CG    C     N     O     CA   
 CB    CD    OE1   OE2   CG   
 C     N     O     CA    CB   
 CD    OE1   OE2   CG    C    
 N     O     CA    CB    CD   
 OE1   OE2   CG    C     N    
 O     CA    CB    CD    OE1  
 OE2   CG    C     N     O    
 CA    CB    CD    OE1   OE2  
 CG    C     N     O     CA   
 CB    CD    OE1   OE2   CG   
SCGLU_RESIDUE_POINTERS    I         30 (20(x,i3))
   1   9  10  18  19  27  28  36  37  45  46  54  55  63  64  72  73  81  82  90
  91  99 100 108 109 117 118 126 127 135
SCGLU_RESIDUE_CG          R         60 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCGLU_ATOMS_IN_RESIDUES   C          9 (1x,5a)
 C     N     O     CA    CB   
 CD    OE1   OE2   CG   
SCHIS_ATOM_XYZ            R        240 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433  -0.624   1.445   3.253   0.760   2.468
   1.910   0.286   3.372   2.749  -0.555   2.779   3.572   0.205   1.241   2.202
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433  -0.241   2.452   1.792   0.324   1.322
   3.572  -0.036   2.529   3.971  -0.382   3.234   2.912   0.205   1.241   2.202
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.926   2.363   2.438  -1.004   1.424
   2.836  -1.012   2.605   3.430   0.146   3.194   3.204   0.205   1.241   2.202
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.859   1.116   1.749   2.838  -1.032
   1.361   4.102  -0.669   1.490   4.143   0.628   1.725   2.029   0.072   1.520
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.959   0.433   0.605   2.724  -0.254
   2.663   4.019  -0.096   2.447   4.188   0.319   1.207   2.029   0.072   1.520
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.935  -0.793   2.032   2.752   1.141
   1.038   4.039   0.930   1.251   4.177  -0.235   1.853   2.029   0.072   1.520
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.858  -2.298   2.599  -1.124  -1.392
   2.727  -1.174  -2.541   3.378   0.013  -3.110   3.315   0.146  -1.209   2.224
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433  -0.805  -1.387   3.171   0.769  -2.429
   2.076   0.217  -3.304   2.898  -0.739  -2.698   3.574   0.146  -1.209   2.224
SCHIS_ATOM_B              R         80 (10(x,f7.4))
 29.0000 29.0000 29.0000 29.0000 29.0000 29.0000 29.0000 29.0000 29.0000 29.0000
  7.0000  7.0000  7.0000  7.0000  7.0000  7.0000  7.0000  7.0000  7.0000  7.0000
 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000
 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000
  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000
 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000
  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000
  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000
SCHIS_RESIDUE_NAME        C          8 (1x,5a)
 Z80   Z81   Z82   Z83   Z84
 Z85   Z86   Z87
SCHIS_RESIDUE_TYPE        C          8 (1x,5a)
 HIS   HIS   HIS   HIS   HIS  
 HIS   HIS   HIS  
SCHIS_ATOM_NAME           C         80 (1x,5a)
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
SCHIS_RESIDUE_POINTERS    I         16 (20(x,i3))
   1  10  11  20  21  30  31  40  41  50  51  60  61  70  71  80
SCHIS_RESIDUE_CG          R         32 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCHIS_ATOMS_IN_RESIDUES   C         10 (1x,5a)
 C     N     O     CA    CB   
 CD2   ND1   CE1   NE2   CG   
SCILE_ATOM_XYZ            R        120 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.564  -0.015   1.433   0.500   1.248   3.646   0.195   1.277
   2.165   2.080  -0.139   1.408   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.564  -0.015   1.433   0.375
   2.520   1.618   0.032   1.180   2.228   2.083   0.060   1.408   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.564  -0.015   1.433   2.710   0.410   2.741   2.092   0.060   1.406   0.157
  -1.292   2.152   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.564  -0.015   1.433   2.629   1.369   0.870
   2.092   0.060   1.406   0.157  -1.292   2.152   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.564  -0.015
   1.433   0.833  -1.502   3.486   0.133  -1.289   2.163   0.057   1.185   2.218
SCILE_ATOM_B              R         40 (10(x,f7.4))
 60.0000 60.0000 60.0000 60.0000 60.0000 60.0000 60.0000 60.0000 15.0000 15.0000
 15.0000 15.0000 15.0000 15.0000 15.0000 15.0000  8.0000  8.0000  8.0000  8.0000
  8.0000  8.0000  8.0000  8.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
SCILE_RESIDUE_NAME        C          5 (1x,5a)
 Z88   Z89   Z90   Z91   Z92  
SCILE_RESIDUE_TYPE        C          5 (1x,5a)
 ILE   ILE   ILE   ILE   ILE  
SCILE_ATOM_NAME           C         40 (1x,5a)
 C     N     O     CA    CB   
 CD1   CG1   CG2   C     N    
 O     CA    CB    CD1   CG1  
 CG2   C     N     O     CA   
 CB    CD1   CG1   CG2   C    
 N     O     CA    CB    CD1  
 CG1   CG2   C     N     O    
 CA    CB    CD1   CG1   CG2  
SCILE_RESIDUE_POINTERS    I         10 (20(x,i3))
   1   8   9  16  17  24  25  32  33  40
SCILE_RESIDUE_CG          R         20 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCILE_ATOMS_IN_RESIDUES   C          8 (1x,5a)
 C     N     O     CA    CB   
 CD1   CG1   CG2  
SCLEU_ATOM_XYZ            R         96 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.690   1.049   3.708   0.943   2.461
   1.705   0.230   1.243   2.271   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433  -0.709
   1.999   2.300   1.317   1.233   3.475   0.661   1.367   2.110   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.587   1.399   1.067   2.455  -0.059   3.049   2.056
   0.072   1.588   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.359   0.952   2.871
   2.754  -1.153   1.653   2.046   0.191   1.592
SCLEU_ATOM_B              R         32 (10(x,f7.4))
 59.0000 59.0000 59.0000 59.0000 59.0000 59.0000 59.0000 59.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000 29.0000 29.0000 29.0000 29.0000
 29.0000 29.0000 29.0000 29.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000
SCLEU_RESIDUE_NAME        C          4 (1x,5a)
 Z93   Z94   Z95   Z96  
SCLEU_RESIDUE_TYPE        C          4 (1x,5a)
 LEU   LEU   LEU   LEU  
SCLEU_ATOM_NAME           C         32 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CG    C     N    
 O     CA    CB    CD1   CD2  
 CG    C     N     O     CA   
 CB    CD1   CD2   CG    C    
 N     O     CA    CB    CD1  
 CD2   CG   
SCLEU_RESIDUE_POINTERS    I          8 (20(x,i3))
   1   8   9  16  17  24  25  32
SCLEU_RESIDUE_CG          R         16 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCLEU_ATOMS_IN_RESIDUES   C          8 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CG   
SCLYS_ATOM_XYZ            R        513 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.805   1.209   3.616   0.514   2.486
   4.387   0.246   1.277   2.204   1.057   2.433   5.773   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433   0.805   1.209   3.616   0.514   2.486   4.387   0.246   1.277
   2.204   1.214   3.662   3.798   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.805
   1.209   3.616   0.514   2.486   4.387   0.246   1.277   2.204  -0.946   2.683
   4.606   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   0.805   1.209   3.616   0.060
   0.183   4.455   0.246   1.277   2.204   0.597   0.104   5.842   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.805   1.209   3.616   0.060   0.183   4.455   0.246
   1.277   2.204  -1.363   0.567   4.668   0.551  -1.198  -0.766  -1.458   0.000
   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433
   0.805   1.209   3.616   2.325   1.209   3.608   0.246   1.277   2.204   2.887
   1.142   4.985   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.805   1.209   3.616
   2.325   1.209   3.608   0.246   1.277   2.204   2.877   2.489   3.082   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   0.822   2.477   1.712   0.429   3.703   2.521
   0.143   1.225   2.242   1.087   4.939   2.013   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.822   2.477   1.712   0.429   3.703   2.521   0.143   1.225   2.242
  -1.021   4.016   2.387   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024
  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.822   2.477
   1.712   2.322   2.435   1.951   0.143   1.225   2.242   3.001   3.657   1.436
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.513   0.069   2.977   4.029   0.141
   3.072   2.051   0.073   1.529   4.497   0.138   4.486   0.551  -1.198  -0.766
  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536
   0.000   1.433   2.513   0.069   2.977   4.029   0.141   3.072   2.051   0.073
   1.529   4.680  -1.070   2.501   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.513
   0.069   2.977   4.029   0.141   3.072   2.051   0.073   1.529   4.557   1.431
   2.547   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.536   0.000   1.433   2.513   0.069   2.977   2.112
   1.351   3.687   2.051   0.073   1.529   2.558   1.362   5.108   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.513   0.069   2.977   2.241  -1.272   3.639   2.051
   0.073   1.529   2.688  -1.291   5.059   0.551  -1.198  -0.766  -1.458   0.000
   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433
   2.570   1.422   1.058   4.085   1.494   1.154   2.051   0.073   1.529   4.608
   2.811   0.696   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.570   1.422   1.058
   4.085   1.494   1.154   2.051   0.073   1.529   4.747   0.532   0.230   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   0.708  -1.159   3.652   0.315  -2.384   4.461
   0.143  -1.225   2.242   0.862  -2.334   5.846   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.708  -1.159   3.652   0.315  -2.384   4.461   0.143  -1.225   2.242
   0.916  -3.631   3.909
SCLYS_ATOM_B              R        171 (10(x,f7.4))
 20.0000 20.0000 20.0000 20.0000 20.0000 20.0000 20.0000 20.0000 20.0000  5.0000
  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  1.0000  1.0000  3.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000
  6.0000  6.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  4.0000  4.0000
  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  4.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  3.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000  1.0000  1.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000  1.0000
  1.0000
SCLYS_RESIDUE_NAME        C         19 (1x,5a)
 Z97   Z98   Z99   Z100  Z101 
 Z102  Z103  Z104  Z105  Z106 
 Z107  Z108  Z109  Z110  Z111 
 Z112  Z113  Z114  Z115 
SCLYS_RESIDUE_TYPE        C         19 (1x,5a)
 LYS   LYS   LYS   LYS   LYS  
 LYS   LYS   LYS   LYS   LYS  
 LYS   LYS   LYS   LYS   LYS  
 LYS   LYS   LYS   LYS  
SCLYS_ATOM_NAME           C        171 (1x,5a)
 C     N     O     CA    CB   
 CD    CE    CG    NZ    C    
 N     O     CA    CB    CD   
 CE    CG    NZ    C     N    
 O     CA    CB    CD    CE   
 CG    NZ    C     N     O    
 CA    CB    CD    CE    CG   
 NZ    C     N     O     CA   
 CB    CD    CE    CG    NZ   
 C     N     O     CA    CB   
 CD    CE    CG    NZ    C    
 N     O     CA    CB    CD   
 CE    CG    NZ    C     N    
 O     CA    CB    CD    CE   
 CG    NZ    C     N     O    
 CA    CB    CD    CE    CG   
 NZ    C     N     O     CA   
 CB    CD    CE    CG    NZ   
 C     N     O     CA    CB   
 CD    CE    CG    NZ    C    
 N     O     CA    CB    CD   
 CE    CG    NZ    C     N    
 O     CA    CB    CD    CE   
 CG    NZ    C     N     O    
 CA    CB    CD    CE    CG   
 NZ    C     N     O     CA   
 CB    CD    CE    CG    NZ   
 C     N     O     CA    CB   
 CD    CE    CG    NZ    C    
 N     O     CA    CB    CD   
 CE    CG    NZ    C     N    
 O     CA    CB    CD    CE   
 CG    NZ    C     N     O    
 CA    CB    CD    CE    CG   
 NZ   
SCLYS_RESIDUE_POINTERS    I         38 (20(x,i3))
   1   9  10  18  19  27  28  36  37  45  46  54  55  63  64  72  73  81  82  90
  91  99 100 108 109 117 118 126 127 135 136 144 145 153 154 162 163 171
SCLYS_RESIDUE_CG          R         76 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCLYS_ATOMS_IN_RESIDUES   C          9 (1x,5a)
 C     N     O     CA    CB   
 CD    CE    CG    NZ   
SCMET_ATOM_XYZ            R        312 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.993   2.730   1.543   2.708   2.414
   1.952   0.205   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.993
   2.730   1.543   0.403   3.983   2.679   0.205   1.258   2.219   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.993   2.730   1.543  -0.387   3.495   0.695   0.205
   1.258   2.219   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.893   1.238   3.886
  -0.288   0.149   4.678   0.246   1.278   2.204   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.893   1.238   3.886   0.387   2.850   4.481   0.246   1.278   2.204
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.893   1.238   3.886   2.643   1.475
   3.580   0.246   1.278   2.204   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.643
   0.069   3.231   2.242   1.742   3.731   2.051   0.072   1.529   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.643   0.069   3.231   4.413   0.160   2.975   2.051
   0.072   1.529   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   2.643   0.069   3.231
   2.406  -1.652   3.669   2.051   0.072   1.529   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   2.716   1.625   0.899   4.470   1.372   1.159   2.051   0.072   1.529
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   2.716   1.625   0.899   2.288   2.741
   2.233   2.051   0.072   1.529   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.792
  -1.187   3.923   2.516  -1.577   3.629   0.143  -1.225   2.243   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   0.792  -1.187   3.923  -0.294   0.021   4.679   0.143
  -1.225   2.243
SCMET_ATOM_B              R        104 (10(x,f7.4))
 19.0000 19.0000 19.0000 19.0000 19.0000 19.0000 19.0000 19.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000
 11.0000 11.0000  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000
 17.0000 17.0000 17.0000 17.0000 17.0000 17.0000 17.0000 17.0000  7.0000  7.0000
  7.0000  7.0000  7.0000  7.0000  7.0000  7.0000  3.0000  3.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000
  5.0000  5.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000  2.0000
  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  3.0000  3.0000
  3.0000  3.0000  3.0000  3.0000  3.0000  3.0000  2.0000  2.0000  2.0000  2.0000
  2.0000  2.0000  2.0000  2.0000
SCMET_RESIDUE_NAME        C         13 (1x,5a)
 Z116  Z117  Z118  Z119  Z120 
 Z121  Z122  Z123  Z124  Z125 
 Z126  Z127  Z128 
SCMET_RESIDUE_TYPE        C         13 (1x,5a)
 MET   MET   MET   MET   MET  
 MET   MET   MET   MET   MET  
 MET   MET   MET  
SCMET_ATOM_NAME           C        104 (1x,5a)
 C     N     O     CA    CB   
 SD    CE    CG    C     N    
 O     CA    CB    SD    CE   
 CG    C     N     O     CA   
 CB    SD    CE    CG    C    
 N     O     CA    CB    SD   
 CE    CG    C     N     O    
 CA    CB    SD    CE    CG   
 C     N     O     CA    CB   
 SD    CE    CG    C     N    
 O     CA    CB    SD    CE   
 CG    C     N     O     CA   
 CB    SD    CE    CG    C    
 N     O     CA    CB    SD   
 CE    CG    C     N     O    
 CA    CB    SD    CE    CG   
 C     N     O     CA    CB   
 SD    CE    CG    C     N    
 O     CA    CB    SD    CE   
 CG    C     N     O     CA   
 CB    SD    CE    CG   
SCMET_RESIDUE_POINTERS    I         26 (20(x,i3))
   1   8   9  16  17  24  25  32  33  40  41  48  49  56  57  64  65  72  73  80
  81  88  89  96  97 104
SCMET_RESIDUE_CG          R         52 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCMET_ATOMS_IN_RESIDUES   C          8 (1x,5a)
 C     N     O     CA    CB   
 SD    CE    CG   
SCPHE_ATOM_XYZ            R        165 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   1.005   2.371   2.107  -0.908   1.294
   3.025   0.700   3.517   2.816  -1.215   2.438   3.736   0.205   1.245   2.204
  -0.410   3.551   3.631   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024
  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.058   2.460
   1.556   0.038   1.204   3.577  -0.247   3.606   2.265  -0.266   2.349   4.289
   0.205   1.245   2.204  -0.410   3.551   3.632   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433  -0.952   1.957   1.934   1.048   1.706   3.199  -1.257   3.103   2.643
   0.745   2.853   3.910   0.205   1.245   2.204  -0.408   3.551   3.632   0.551
  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000
   0.000   0.536   0.000   1.433   2.693   1.280   1.376   2.784  -1.068   1.746
   4.071   1.347   1.456   4.162  -1.005   1.825   2.033   0.072   1.520   4.806
   0.203   1.681   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.944  -2.343   2.232
  -1.024  -1.226   2.968   0.583  -3.459   2.963  -1.388  -2.341   3.699   0.144
  -1.213   2.226  -0.583  -3.458   3.696
SCPHE_ATOM_B              R         55 (10(x,f7.4))
 44.0000 44.0000 44.0000 44.0000 44.0000 44.0000 44.0000 44.0000 44.0000 44.0000
 44.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000
  9.0000  9.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000 33.0000 33.0000 33.0000 33.0000 33.0000 33.0000 33.0000
 33.0000 33.0000 33.0000 33.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000
 13.0000 13.0000 13.0000 13.0000 13.0000
SCPHE_RESIDUE_NAME        C          5 (1x,5a)
 Z129  Z130  Z131  Z132  Z133 
SCPHE_RESIDUE_TYPE        C          5 (1x,5a)
 PHE   PHE   PHE   PHE   PHE  
SCPHE_ATOM_NAME           C         55 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CE1   CE2   CG   
 CZ    C     N     O     CA   
 CB    CD1   CD2   CE1   CE2  
 CG    CZ    C     N     O    
 CA    CB    CD1   CD2   CE1  
 CE2   CG    CZ    C     N    
 O     CA    CB    CD1   CD2  
 CE1   CE2   CG    CZ    C    
 N     O     CA    CB    CD1  
 CD2   CE1   CE2   CG    CZ   
SCPHE_RESIDUE_POINTERS    I         10 (20(x,i3))
   1  11  12  22  23  33  34  44  45  55
SCPHE_RESIDUE_CG          R         20 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCPHE_ATOMS_IN_RESIDUES   C         11 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CE1   CE2   CG   
 CZ   
SCPRO_ATOM_XYZ            R         42 (10(x,f7.3))
   0.566  -1.218  -0.723   0.000   0.000   0.000   0.344   0.000   1.491  -2.018
   0.150   1.357  -0.835   0.687   2.142  -1.466   0.000   0.000  -0.181  -2.059
  -1.222   0.000   0.000   0.000   0.344   0.000   1.491  -2.018  -0.228   1.347
  -0.821  -0.669   2.141  -1.466   0.000   0.000   0.566  -1.368  -0.364  -0.181
  -2.313  -0.616
SCPRO_ATOM_B              R         14 (10(x,f7.4))
 50.0000 50.0000 50.0000 50.0000 50.0000 50.0000 50.0000 50.0000 50.0000 50.0000
 50.0000 50.0000 50.0000 50.0000
SCPRO_RESIDUE_NAME        C          2 (1x,5a)
 Z134  Z135 
SCPRO_RESIDUE_TYPE        C          2 (1x,5a)
 PRO   PRO  
SCPRO_ATOM_NAME           C         14 (1x,5a)
 C     CA    CB    CD    CG   
 N     O     CA    CB    CD   
 CG    N     C     O    
SCPRO_RESIDUE_POINTERS    I          4 (20(x,i3))
   1   7   8  14
SCPRO_RESIDUE_CG          R          8 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCPRO_ATOMS_IN_RESIDUES   C          7 (1x,5a)
 C     CA    CB    CD    CG   
 N     O    
SCSER_ATOM_XYZ            R         54 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.133  -1.167   2.128   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   1.951   0.069   1.448   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.192   1.198   2.106
SCSER_ATOM_B              R         18 (10(x,f7.4))
 48.0000 48.0000 48.0000 48.0000 48.0000 48.0000 22.0000 22.0000 22.0000 22.0000
 22.0000 22.0000 29.0000 29.0000 29.0000 29.0000 29.0000 29.0000
SCSER_RESIDUE_NAME        C          3 (1x,5a)
 Z136  Z137  Z138 
SCSER_RESIDUE_TYPE        C          3 (1x,5a)
 SER   SER   SER  
SCSER_ATOM_NAME           C         18 (1x,5a)
 C     N     O     CA    CB   
 OG    C     N     O     CA   
 CB    OG    C     N     O    
 CA    CB    OG   
SCSER_RESIDUE_POINTERS    I          6 (20(x,i3))
   1   6   7  12  13  18
SCSER_RESIDUE_CG          R         12 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCSER_ATOMS_IN_RESIDUES   C          6 (1x,5a)
 C     N     O     CA    CB   
 OG   
SCTHR_ATOM_XYZ            R         63 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.564  -0.015   1.433   0.057   1.185   2.218   0.150  -1.214
   2.100   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.564  -0.015   1.433   0.199  -1.314   2.136   1.992
   0.103   1.389   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.564  -0.015   1.433   2.080  -0.139   1.408
   0.209   1.202   2.102
SCTHR_ATOM_B              R         21 (10(x,f7.4))
 49.0000 49.0000 49.0000 49.0000 49.0000 49.0000 49.0000  7.0000  7.0000  7.0000
  7.0000  7.0000  7.0000  7.0000 43.0000 43.0000 43.0000 43.0000 43.0000 43.0000
 43.0000
SCTHR_RESIDUE_NAME        C          3 (1x,5a)
 Z139  Z140  Z141 
SCTHR_RESIDUE_TYPE        C          3 (1x,5a)
 THR   THR   THR  
SCTHR_ATOM_NAME           C         21 (1x,5a)
 C     N     O     CA    CB   
 CG2   OG1   C     N     O    
 CA    CB    CG2   OG1   C    
 N     O     CA    CB    CG2  
 OG1  
SCTHR_RESIDUE_POINTERS    I          6 (20(x,i3))
   1   7   8  14  15  21
SCTHR_RESIDUE_CG          R         12 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCTHR_ATOMS_IN_RESIDUES   C          7 (1x,5a)
 C     N     O     CA    CB   
 CG2   OG1  
SCTRP_ATOM_XYZ            R        294 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433  -0.857   1.430   3.038   0.936   2.475
   2.192   0.261   3.364   3.052   2.095   2.910   1.544  -0.833   2.702   3.557
   0.203   1.244   2.198   1.845   5.067   2.635   0.706   4.665   3.282   2.536
   4.200   1.771   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433  -0.438   2.352   1.722
   0.493   1.506   3.577   0.000   2.793   3.867   1.121   0.777   4.589  -0.565
   3.290   2.717   0.203   1.244   2.198   0.734   2.635   6.107   0.114   3.369
   5.131   1.235   1.349   5.842   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.947
   2.386   2.269  -0.964   1.470   2.999  -0.858   2.772   3.527  -2.083   0.698
   3.320   0.318   3.313   3.066   0.203   1.244   2.198  -2.920   2.545   4.659
  -1.832   3.322   4.360  -3.048   1.243   4.147   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   2.794   1.201   1.579   2.940  -1.035   1.540   4.241  -0.499   1.621
   2.781  -2.422   1.503   4.126   0.870   1.643   2.030   0.072   1.514   5.196
  -2.661   1.627   5.379  -1.304   1.665   3.909  -3.219   1.546   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.884  -0.948   1.821   2.846   1.228   1.283   4.185
   0.833   1.469   2.572   2.554   0.939   4.183  -0.502   1.797   2.030   0.072
   1.514   4.958   3.013   0.983   5.252   1.718   1.322   3.630   3.431   0.794
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   0.830  -2.387   2.313  -1.033  -1.365
   3.026  -0.991  -2.661   3.577  -2.113  -0.534   3.333   0.158  -3.267   3.127
   0.142  -1.212   2.220  -3.037  -2.312   4.706  -1.989  -3.147   4.421  -3.102
  -1.016   4.168   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433  -0.976  -1.363   2.988
   0.868  -2.445   2.314   0.128  -3.297   3.158   2.067  -2.907   1.768  -0.995
  -2.613   3.557   0.142  -1.212   2.220   1.728  -5.019   2.921   0.549  -4.589
   3.469   2.484  -4.188   2.077
SCTRP_ATOM_B              R         98 (10(x,f7.4))
 32.0000 32.0000 32.0000 32.0000 32.0000 32.0000 32.0000 32.0000 32.0000 32.0000
 32.0000 32.0000 32.0000 32.0000  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000
  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000  8.0000  5.0000  5.0000
  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000  5.0000
  5.0000  5.0000 18.0000 18.0000 18.0000 18.0000 18.0000 18.0000 18.0000 18.0000
 18.0000 18.0000 18.0000 18.0000 18.0000 18.0000 16.0000 16.0000 16.0000 16.0000
 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000 16.0000
  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000
  6.0000  6.0000  6.0000  6.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000
 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000 11.0000
SCTRP_RESIDUE_NAME        C          7 (1x,5a)
 Z142  Z143  Z144  Z145  Z146 
 Z147  Z148 
SCTRP_RESIDUE_TYPE        C          7 (1x,5a)
 TRP   TRP   TRP   TRP   TRP  
 TRP   TRP  
SCTRP_ATOM_NAME           C         98 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CE2   CE3   NE1  
 CG    CH2   CZ2   CZ3   C    
 N     O     CA    CB    CD1  
 CD2   CE2   CE3   NE1   CG   
 CH2   CZ2   CZ3   C     N    
 O     CA    CB    CD1   CD2  
 CE2   CE3   NE1   CG    CH2  
 CZ2   CZ3   C     N     O    
 CA    CB    CD1   CD2   CE2  
 CE3   NE1   CG    CH2   CZ2  
 CZ3   C     N     O     CA   
 CB    CD1   CD2   CE2   CE3  
 NE1   CG    CH2   CZ2   CZ3  
 C     N     O     CA    CB   
 CD1   CD2   CE2   CE3   NE1  
 CG    CH2   CZ2   CZ3   C    
 N     O     CA    CB    CD1  
 CD2   CE2   CE3   NE1   CG   
 CH2   CZ2   CZ3  
SCTRP_RESIDUE_POINTERS    I         14 (20(x,i3))
   1  14  15  28  29  42  43  56  57  70  71  84  85  98
SCTRP_RESIDUE_CG          R         28 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCTRP_ATOMS_IN_RESIDUES   C         14 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CE2   CE3   NE1  
 CG    CH2   CZ2   CZ3  
SCTYR_ATOM_XYZ            R        180 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.536   0.000   1.433   1.005   2.383   2.118  -0.912   1.301
   3.038   0.708   3.531   2.826  -1.225   2.441   3.754   0.203   1.253   2.212
  -0.716   4.695   4.354  -0.414   3.555   3.646   0.551  -1.198  -0.766  -1.458
   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000
   1.433   0.056   2.474   1.566   0.037   1.210   3.590  -0.248   3.623   2.270
  -0.267   2.349   4.310   0.203   1.253   2.212  -0.712   4.694   4.357  -0.410
   3.555   3.649   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.536   0.000   1.433  -0.956   1.969   1.945
   1.050   1.715   3.211  -1.268   3.115   2.651   0.755   2.858   3.928   0.203
   1.253   2.212  -0.707   4.696   4.355  -0.405   3.557   3.647   0.551  -1.198
  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000   0.000   0.000
   0.536   0.000   1.433   2.708   1.284   1.381   2.799  -1.071   1.751   4.084
   1.359   1.461   4.176  -1.015   1.835   2.044   0.073   1.523   6.189   0.267
   1.772   4.818   0.201   1.690   0.551  -1.198  -0.766  -1.458   0.000   0.000
   0.024  -2.306  -0.667   0.000   0.000   0.000   0.536   0.000   1.433   0.944
  -2.355   2.242  -1.029  -1.235   2.980   0.593  -3.474   2.971  -1.397  -2.345
   3.715   0.143  -1.221   2.234  -0.942  -4.574   4.438  -0.584  -3.464   3.710
SCTYR_ATOM_B              R         60 (10(x,f7.4))
 43.0000 43.0000 43.0000 43.0000 43.0000 43.0000 43.0000 43.0000 43.0000 43.0000
 43.0000 43.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000  9.0000
  9.0000  9.0000  9.0000  9.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000
  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000 34.0000 34.0000 34.0000 34.0000
 34.0000 34.0000 34.0000 34.0000 34.0000 34.0000 34.0000 34.0000 13.0000 13.0000
 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000 13.0000
SCTYR_RESIDUE_NAME        C          5 (1x,5a)
 Z149  Z150  Z151  Z152  Z153 
SCTYR_RESIDUE_TYPE        C          5 (1x,5a)
 TYR   TYR   TYR   TYR   TYR  
SCTYR_ATOM_NAME           C         60 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CE1   CE2   CG   
 OH    CZ    C     N     O    
 CA    CB    CD1   CD2   CE1  
 CE2   CG    OH    CZ    C    
 N     O     CA    CB    CD1  
 CD2   CE1   CE2   CG    OH   
 CZ    C     N     O     CA   
 CB    CD1   CD2   CE1   CE2  
 CG    OH    CZ    C     N    
 O     CA    CB    CD1   CD2  
 CE1   CE2   CG    OH    CZ   
SCTYR_RESIDUE_POINTERS    I         10 (20(x,i3))
   1  12  13  24  25  36  37  48  49  60
SCTYR_RESIDUE_CG          R         20 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCTYR_ATOMS_IN_RESIDUES   C         12 (1x,5a)
 C     N     O     CA    CB   
 CD1   CD2   CE1   CE2   CG   
 OH    CZ   
SCVAL_ATOM_XYZ            R         63 (10(x,f7.3))
   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667   0.000
   0.000   0.000   0.564  -0.015   1.433   2.080  -0.139   1.408   0.199   1.269
   2.162   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306  -0.667
   0.000   0.000   0.000   0.564  -0.015   1.433   0.096   1.211   2.203   0.096
  -1.257   2.176   0.551  -1.198  -0.766  -1.458   0.000   0.000   0.024  -2.306
  -0.667   0.000   0.000   0.000   0.564  -0.015   1.433   0.157  -1.292   2.152
   2.083   0.060   1.408
SCVAL_ATOM_B              R         21 (10(x,f7.4))
 73.0000 73.0000 73.0000 73.0000 73.0000 73.0000 73.0000 20.0000 20.0000 20.0000
 20.0000 20.0000 20.0000 20.0000  6.0000  6.0000  6.0000  6.0000  6.0000  6.0000
  6.0000
SCVAL_RESIDUE_NAME        C          3 (1x,5a)
 Z154  Z155  Z156 
SCVAL_RESIDUE_TYPE        C          3 (1x,5a)
 VAL   VAL   VAL  
SCVAL_ATOM_NAME           C         21 (1x,5a)
 C     N     O     CA    CB   
 CG1   CG2   C     N     O    
 CA    CB    CG1   CG2   C    
 N     O     CA    CB    CG1  
 CG2  
SCVAL_RESIDUE_POINTERS    I          6 (20(x,i3))
   1   7   8  14  15  21
SCVAL_RESIDUE_CG          R         12 (4(x,f7.5))
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
 0.53600 0.00000 1.43300 5.14000
SCVAL_ATOMS_IN_RESIDUES   C          7 (1x,5a)
 C     N     O     CA    CB   
 CG1   CG2  
SCALA_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCARG_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCASN_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCASP_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCCYH_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCCYS_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCGLN_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCGLU_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCHIS_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCILE_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCLEU_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCLYS_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCMET_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCPHE_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCPRO_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCSER_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCTHR_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCTRP_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCTYR_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O
SCVAL_MC_ATOMS            C          4 (1x,5a)
 N     CA    C     O' > rsc_duke.odb

#make on_startup file
echo -e "! read database files" > on_startup
echo -e "read menu_raymond.odb" >> on_startup
echo -e "read resid.odb" >> on_startup
echo -e "read stereochem_duke10.odb" >> on_startup
echo -e "read rsc_duke.odb\n" >> on_startup

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
				echo -e "Please send MTZ to raymond@crystal.harvard.edu to update script"
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

#Finish script
echo -e "\nScript finished\n"
