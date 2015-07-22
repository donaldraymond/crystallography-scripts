#!/bin/bash

#script to make O macros and menus

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

echo '.MENU                     T          46         40
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

echo '.ID_TEMPLATE         T          2         40
%Restyp %RESNAM %ATMNAM
residue_2ry_struc' > $O_dir/resid.odb

#make O macro file
echo '! read database files" > $O_dir/O_mac
read .O_files/menu_raymond.odb
read old/residue_dict.odb
read .O_files/resid.odb
' > $O_dir/O_mac

echo '! open menus
win_open user_menu -1.66 0.49
win_open object_menu -1.66 0.94
win_open dial_menu 1.44 -0.34
win_open paint_display 1.14 -0.34
' >> $O_dir/O_mac

#give instructions for running in O
echo -e "\nExecute the following in O\n
@.O_files/O_mac\n"
