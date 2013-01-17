#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

for rnum in `seq 1 10`; do 
    wget -O /dev/null --header='Content-type: text/json' --post-data=' ' --no-check-certificate "${PBREST_URI}/rounds/TestRound${rnum}"
    for pnum in `seq 1 10`; do 
	wget -O /dev/null --no-check-certificate "${PB_BIN_URI}/newpuzzle.pl?puzzurl=https%3A%2F%2Fwww.google.com%2F&puzzid=TestPuzzR${rnum}P${pnum}&round=TestRound${rnum}"
    done
done
