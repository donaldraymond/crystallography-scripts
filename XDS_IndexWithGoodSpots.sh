#!/bin/bash

#Exit after first nonzero exit code
set -e

#script to re-index with only good spots
######################################################################

#create list of bad spots
egrep " 0 0 0" SPOT.XDS > SPOT.XDS_bad

#create list of good spots
egrep -v " 0 0 0" SPOT.XDS > SPOT.XDS_good

#save original spot list
mv SPOT.XDS SPOT.XDS_orig

#move good spot list to SPOT.XDS
cp SPOT.XDS_good SPOT.XDS

echo;echo "Making new XDS.INP file for indexing";echo

#get everything for XDS.INP except JOB= cards
egrep -v "JOB=" XDS.INP > XDS.INP_temp

#save original XDS.INP file
cp XDS.INP XDS.INP_old

#JOB= cards for new XDS.INP 
echo "!JOB= ALL !XYCORR INIT COLSPOT IDXREF DEFPIX XPLAN INTEGRATE CORRECT" > XDS.INP_SPOTS
echo "!JOB= XYCORR INIT COLSPOT IDXREF" >> XDS.INP_SPOTS
echo " JOB= IDXREF DEFPIX XPLAN INTEGRATE CORRECT" >> XDS.INP_SPOTS
echo "!JOB= DEFPIX INTEGRATE CORRECT" >> XDS.INP_SPOTS
echo "!JOB= CORRECT" >> XDS.INP_SPOTS

# finish XDS.INP
cat  XDS.INP_temp >> XDS.INP_SPOTS
cp XDS.INP_SPOTS XDS.INP

#Remove temp files
rm XDS.INP_temp

#Run XDS
echo "Running XDS for indexing";echo
xds_par

