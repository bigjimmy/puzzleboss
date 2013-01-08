#!/bin/bash

for rnum in `seq 1 10`; do 
    wget -O /dev/null --header='Content-type: text/json' --post-data=' ' --no-check-certificate "https://wind-up-birds.org/puzzlebitch-jrandall/bin/pbrest.pl/rounds/TestRound${rnum}"
    for pnum in `seq 1 10`; do 
	wget -O /dev/null --no-check-certificate "https://wind-up-birds.org/puzzlebitch-jrandall/bin/newpuzzle.pl?puzzurl=https%3A%2F%2Fwww.google.com%2F&puzzid=TestPuzzR${rnum}P${pnum}&round=TestRound${rnum}"
    done
done
