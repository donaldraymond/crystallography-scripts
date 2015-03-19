#! /bin/bash

# a script to convert phenix and refmac formatted TLS file for use in buster

#for debugging
#set -x

#clear screen
clear

#check for input TLS file
if [[ -f $1 ]] ; then
	tlsfile=$1
else 
	echo -e "\nNo input file specified\n"
	exit 1
fi

#check for format 
if grep -q "refinement.refine {" $tlsfile; then
	echo -e "\nConverting from phenix to Buster TLS format\n"
	mode=phenix
elif grep -q "RANGE  " $tlsfile; then
	echo -e "\nConverting from refmac to Buster TLS format\n"
	mode=refmac
else
	echo -e "\nUnknow format\n"
	exit 1
fi	

#make buster file
>Buster.TLSMD

#function to extract info from phenix formatted TLS file
function phenixTLS {
	#ignore line without tls=
	if ! [[ $line =~ ^"tls=" ]]; then 
		continue 
	fi 

	#get chain
	chain=`echo "$line" | awk -F' ' '{print $2}'`

	#get start
	start=`echo "$line" | awk -F' |:' '{print $5}'`

	#get end 
	end=`echo "$line" | awk -F' |:' '{print $6}' | awk -F'\)' '{print $1}' 2>/dev/null`

	# get current number of ranges
	numb=`grep "NOTE BUSTER_TLS_SET tls"$chain"" Buster.TLSMD | wc -l`

	#output line to Buster.txt
	echo "NOTE BUSTER_TLS_SET tls"$chain"`expr $numb + 1` {$chain|$start - $end}" >>Buster.TLSMD 
}


#function to extract info from refmac formatted TLS file
function refmacTLS {
	#ignore line without RANGE  '
	if ! [[ $line =~ ^"RANGE  '" ]]; then 
		continue
	fi 

	#get chain
	chain=`echo "$line" | awk -F' ' '{print $2}' | awk -F"'" '{print $2}'`

	#get start
	start=`echo "$line" | awk -F' ' '{print $3}' | awk -F"." '{print $1}'`

	#get end 
	end=`echo "$line" | awk -F' ' '{print $5}' | awk -F"." '{print $1}'`

	# get current number of ranges
	numb=`grep "NOTE BUSTER_TLS_SET tls"$chain"" Buster.TLSMD | wc -l`

	#output line to Buster.txt
	echo "NOTE BUSTER_TLS_SET tls"$chain"`expr $numb + 1` {$chain|$start - $end}" >>Buster.TLSMD 
}

#Run right function
while read line; do
	if [ $mode = "phenix" ]; then
		phenixTLS
	elif [ $mode = "refmac" ]; then
		refmacTLS
	fi
done < $tlsfile

#Finish script
echo -e "Script finish\n"
