#!/bin/bash

# A script to add map to on_startup O file

#for debugging
#set -x

O_dir=".O_files"

#check for on_startup file and .O_files/
if [ ! -e "on_startup"  ] || [ ! -d "$O_dir" ]; then
	echo -e "No on_startup file or $O_dir found"
	exit 1
fi

#check for *.ccp4 file
if ! [[ "$1" = *.ccp4 ]]; then
	echo -e "This script needs a map file"
	exit 1
fi

#check if map is already in on_startup
if grep -q "fm_file $1" on_startup; then
	echo -e "\n$1 is already in the on_startup file\n"
	exit 1
fi

#get map number 
mapNum=`grep -c "fm_file" on_startup`

#get map name
echo
read -e -p "Name of map [map]: " -n 6 mapName
while [[ -z $mapName ]]; do
	mapName=map
done

#get spacegroup
spacegroup="`awk '/fm_file/ {print $4; exit}' on_startup`"

#append file
echo "
fm_file $1 $mapName $spacegroup
Fm_setup $mapName 40 ; 1 1.1 magenta" >> on_startup

#append density_window information
case $mapNum in
	1)	echo "window_open density_2 1.06 0.65" >> on_startup
		;;
	2)	echo "window_open density_3 1.06 0.32" >> on_startup
		;;
	3)	echo "window_open density_4 1.06 -0.01" >> on_startup
		;;
	*)	echo "Unknown option..not appending density window info"
		;;
esac

echo "fm_draw $mapName" >> $O_dir/next_water
echo "fm_draw $mapName" >> $O_dir/next_ca
echo "fm_draw $mapName" >> $O_dir/previous_ca
echo "fm_draw $mapName" >> $O_dir/redraw_map

#End
echo -e "\nMap info appending to O macro files\n"
