# Scripts for X-ray crystallography

These are a collection of scripts that I wrote to help with specific tasks in X-ray crystallography. I started this project to learn bash scripting and will push updates whenever I can.

Most of the scripts in this git repository require the [CCP4](http://www.ccp4.ac.uk) package. I try to use CCP4 programs exclusively to ensure general compatibility. When I use program outside of the CCP4 suite, I run a check to see if that program is installed before running the script.

Check permissions before the scripts. Use `chmod +x script.sh` to make the script executable

Report bugs or feature request to *raymond [at] crystal.harvard.edu*

## grabPDB.sh

The purpose of this script is to download atomic coordinates and reflections files from the [Protein Data Bank.](www.rcsb.org)

The user can either pass the script a PDB ID in the command line e.g. `grabPDB.sh 1yks` or input the ID when asked.

The script downloads the PDB and sf.mmCIF files from the PDB. It then converts the cif file to an MTZ using CIF2MTZ and then calculates map coefficients using REFMAC5.

After running the script the PDB and MTZ files can be opened in COOT, PyMOL to visualize the maps and model. To get the maps and PDB into O use the makeO.sh script described below.

## PDBget.sh

This script just downloads a PDB file from the Protein Data Bank.

The user can either pass the script a PDB ID in the command line e.g. `PDBget.sh 1yks` or input the ID when asked.

## PDB_ideal.sh
The purpose of this script is to idealize the geometry of a model using refmac5. The script takes a PDB file as input and output a PDB with the idealize model. No MTZ file is required. I use this script before refining low resolution structures to help the refinement program out.

## busterTLS.sh
This script converts phenix or refmac TLS input files to buster format. I use the TLS.MD server to get the phenix or refmac TLS input files and use this script to convert it to buster format.

## makeO.sh

The purpose of this script is to quickly generate CCP4 maps from an MTZ and get the maps and associated PDB into the [O graphics program](http://xray.bmc.uu.se/alwyn/TAJ/Home.html). This script is fully automated and only requires the user to specify the MTZ, the PDB, and a prefix for the CCP4 maps.

The script using fft for generating the maps and then uses mapmask to normalize the map. It creates an on_startup O macro file with the map and model already added.

Run like this `makeO.sh file.mtz file.pdb`, or simple run `makeO.sh` and follow instructions.


## pdb2O.sh 

This script combines the functionality of grabPDB.sh and makeO.sh. Essentially, it will download coordinate and reflection files from the PDB, generate maps and create an O macro to get the maps and PDB into O upon launch. Just run the script with a PDB ID and sit back and relax.

## makemap.sh

This is a stripped-down version of the makeO.sh script. All it does is make maps from an mtz with map coefficients.

## O_insertSeq.sh

This script generates the O commands to insert residues into the database. It is most useful during building.

## sacom.sh

This is a script to make a simulated annealing composite omit map using phenix.autobuild. Run the script by passing a PDB and an MTZ file. The sacom map is less biased than a 2FoFc map and is used to validate the model or fix bad regions.

## XDS scripts

The following scripts deal specifically with [XDS](http://xds.mpimf-heidelberg.mpg.de).

### XDS_refine.sh

This is a bash script to reprocess data with XDS using the correct spacegroup, refined geometry and fine-slicing of profiles AND/OR with refined values for beam divergence and mosaicity

### XDS_IndexWithGoodSpots.sh

Sometime XDS stops because < 50% of spots get indexed. This can be due to numerous reasons including split lattice. This script reindexes using only the good spots in the SPOTS.XDS file.

### XDS_scale.sh

This script runs XSCALE and XDSCONV after data processing to creates an MTZ file.

### XDS_truncate.sh

A script to create an MTZ file from XDS_ASCII.HKL and convert I to F. This script is superseded by XDS_scale.sh since XDSCONV can convert I to F.
