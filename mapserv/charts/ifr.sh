#! /bin/bash
set -x
if [ a$1 == a ] ; then
echo must provide date
exit 1
fi
mkdir ../enrl/$1 ../enrh/$1 ../enra/$1

for i in [E-Z]*.zip  ; do unzip -o $i ; done
mv ENR_AKL*tif ../enrl/$1/
mv ENR_AKH*tif ../enrh/$1/
mv ENR_A*tif ../enra/$1/
mv ENR_[PL]*tif ../enrl/$1/
mv ENR_H*tif ../enrh/$1/

