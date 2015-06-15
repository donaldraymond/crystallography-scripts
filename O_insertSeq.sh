#!/bin/bash

#script to insert residue into O database
#written by Donald Raymond (Jan 4 2015)

########################################################

#clear screen
clear

#delete existing mutate_insert.txt
> mutate_insert.txt

echo '
***************************************************************

This script will create O macros to append residues
or mutate existing sequences in the O database.
New residues can only be appended to an existing PDB

***************************************************************
'
#Function to Ask user for information 1-prompt; 2- number of characters
function ask {
 read -p "$1"": " -n $2 -e val
 echo $val
}

#get molecule name
molecule=$(ask "What is the molecule's name? (6 or less characters)" 6)
echo

#get chain ID 
chain=$(ask "What is the chain ID? (1 character)" 1)
echo

#get starting residue
starting_residue=$(ask "Position of first residue to insert or mutate" 5)
echo

#get sequence
sequence_string=$(ask "Insert sequence" 1000)

#remove spaces, tabs ,etc from sequences
sequence=${sequence_string//[[:blank:]]/}

#print insert or mutate commands for ono
for (( i=0; i<${#sequence}; i++ )); do
  current_value=${sequence:$i:1}
  
  case $current_value in
          
        A | a)   res="Ala"
                ;;
        C | c)   res="Cys"
                ;;
        D | d)   res="Asp"
                ;;
        E | e)   res="Glu"
                ;;
        F | f)   res="Phe"
                ;;
        G | g)   res="Gly"
                ;;
        H | h)   res="His"
                ;;
        I | i)   res="Ile"
                ;;
        K | k)   res="Lys"
                ;;
        L | l)   res="Leu"
                ;;
        M | m)   res="Met"
                ;;
        N | n)   res="Asn"
                ;;
        P | p)   res="Pro"
                ;;
        Q | q)   res="Gln"
                ;;
        R | r)   res="Arg"
                ;;
        S | s)   res="Ser"
                ;;
        T | t)   res="Thr"
                ;;
        V | v)   res="Val"
                ;;
        W | w)   res="Trp"
                ;;
        Y | y)   res="Tyr"
                ;;
        *)  echo -e "\n$current_value is not a valid residue ID. Check sequence and try again\n" ; rm mutate_insert.txt; exit 1
                ;;
    esac
         
    echo "mutate_insert $molecule $chain`expr $starting_residue + $i - 1` $chain`expr $starting_residue + $i` $res ;" >> mutate_insert.txt 

done

echo '
Copy and paste the following lines into the O command line
OR type in @mutate_insert.txt in the O command line
'
cat mutate_insert.txt

echo
