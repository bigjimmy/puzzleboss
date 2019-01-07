#!/usr/bin/python

import sys

try:
 	filename = sys.argv[1] 
except Exception:
	print 'error:  no file provided'
	sys.exit(2)

try:
	fh = open(filename, "r+")
except Exception, e: 
	print e
	sys.exit(2)

positionfilename = filter(str.isalpha, filename)
positionfile = "/tmp/" + positionfilename

try:
	ph = open(positionfile, "rw+")
	startpos = float(ph.read())
	fh.seek(startpos)
	
except:
	# this is OK lets just make a new file
	print "making new positionfile at ", positionfile

for myline in fh:
	if "EROR" in myline:
		print "ERROR FOUND: ", myline

curpos = fh.tell()

try:
	ph.seek(0)
	ph.write(str(curpos) + "\n")
except:
	print "Fatal error updating positionfile at ", positionfile
	sys.exit(2)

	
