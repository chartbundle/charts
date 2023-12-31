#! /bin/bash
set -x
if [ a$1 == a ] ; then
echo must provide date
exit 1
fi
mkdir ../sec/$1 ../tac/$1 ../hel/$1 ../misc/$1

mv *SEC*tif ../sec/$1/
mv *TAC*tif *FLY*  ../tac/$1/
mv *HEL*tif ../hel/$1/
mv Grand*tif ../misc/$1/
mv Cari*tif ../sec/$1/
