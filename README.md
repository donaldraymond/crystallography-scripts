# Scripts for X-ray crystallography

These are a collection of scripts that I wrote to help with specific tasts in X-ray crystallography. I started this project to learn bash scripting and will push updates when ever I can.

Most of the scripts in this git repository require the [CCP4](http://www.ccp4.ac.uk) package. I try to use CCP4 programs exclusively to ensure that general compatibility. When I use program outside of the CCP4 suite, I run a check to see if that program is installed before running the script.

Check permissions before the scripts. Use `chmod +x script.sh` to make the script executable

## grabPDB.sh

The purpose of this script is to download atomic coordinates and reflections files from the [Protein Data Bank.](www.rcsb.org)

The user can either pass the script a PDB ID in the command line e.g. `grabPDB.sh 1yks` or input the ID when asked.

The script downloads the PDB and sf.mmCIF files from the PDB. It then converts the cif file to an MTZ using CIF2MTZ and then calculates map coefficients using REFMAC5.

After running the script the PDB and MTZ files can be opened in COOT, PyMOL to visualize the maps and model. To get the maps and PDB into O use the makeO.sh script described below.

## makeO.sh

The purpose of this script is to quickly generate CCP4 maps from an MTZ and get the maps and associated PDB into the O graphics program. This script is fully automated an only requires the user to specify the MTZ, the PDB, and a prefix for the CCP4 maps.

Run like this `makeO.sh file.mtz file.pdb`, or simple run `makeO.sh` and follow instructions.