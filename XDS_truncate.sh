#!/bin/bash

#Exit after first nonzero exit code
set -e

#A bash script to create an MTZ file from XDS_ASCII.HKL and convert I to F 

###################################################################

#Define truncate command
truncate=$CCP4/bin/truncate

 #Ask user for output file name
 echo -n "Output file name (eg SCH0312.mtz):" 
 read filename
 output="$filename"

##################################################3

#check for log directory
if [ ! -d log ]; then
    mkdir log;
	echo "Creating log directory";echo
else
	echo "Log directory already exists";echo
fi;


# Create and run  XDSCONV.INP 
echo "INPUT_FILE=XDS_ASCII.HKL" > XDSCONV.INP
echo "OUTPUT_FILE=dataset.CCP4_I CCP4_I" >> XDSCONV.INP
echo "FRIEDEL'S_LAW=TRUE" >> XDSCONV.INP

echo "Running xdsconv";echo
xdsconv > log/xdsconf.log

#convert to MTZ
echo "Converting to MTZ";echo
f2mtz HKLOUT tmp1.mtz < F2MTZ.INP > log/f2mtz.log
cad HKLIN1 tmp1.mtz HKLOUT tmp2.mtz << EOF > log/cad.log
 LABIN FILE 1 ALL
 END
EOF

#run truncate
echo "Running truncate";echo
$truncate HKLIN "tmp2.mtz" HKLOUT "tmp3.mtz" << eof > log/truncate.log
truncate YES
anomalous NO
nresidue 888
plot OFF
header BRIEF BATCH
labin IMEAN=IMEAN SIGIMEAN=SIGIMEAN 
labout IMEAN=I SIGIMEAN=SIGI F=F SIGF=SIGF 
#falloff no cone 30.0 PLTX
falloff yes
NOHARVEST
end
eof

#Running mtzutil
echo "Running MTZ UTILITIES";echo
mtzutils HKLIN tmp3.mtz HKLOUT "$output" << eof > log/mtzutils.log
include F SIGF 
eof

echo "Created $output file";echo

#clean up files
echo "Cleaning up";echo
rm XDSCONV.INP XDSCONV.LP F2MTZ.INP tmp1.mtz dataset.CCP4_I tmp2.mtz tmp3.mtz

#Finish
echo "DONE!!";echo
