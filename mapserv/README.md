Charts are placed in the directories named charts/chart_type/YYYYMMDD

Then bin/makemap3.pl is run to generate optimized files and mapfiles. Updates files in mapfiles/includes

mapserv.conf for Apache runs the mapserver. 

mapserver binary not included.
https://mapserver.org/

Also needs GDAL, including Perl bindings, proj4, probably other stuff.

charts/bref contains crop data

ifr.sh and vfr.sh can be used to move a set of files downloaded into work/ to the proper directories.

files in charts/index are created dynamically for speed

