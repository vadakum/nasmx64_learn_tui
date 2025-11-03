#!/bin/bash

#
# This is not part of the termbox2 library.
# Extract #defines from termbox2.h 
#

outfile="auto_gen_termbox2_def.asm"

cmd="gcc -E -P -dD -DTB_IMPL -DTB_LIB_OPTS termbox2.h" 

echo
echo "command: $cmd"

echo "generating nasm %define file : $outfile"

echo "; generated using gen_def_externs.sh" > $outfile
echo "; command used: $cmd" >> $outfile

$cmd | grep '#define TB_' | sed 's/#/%/' >> $outfile
echo "*** Generated file: $outfile "

echo
echo "Note!"
echo "To extract the function and structure definitions run the "
echo "command [$cmd] and manually copy the required definitions."
