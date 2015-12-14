#!/bin/bash

wget http://repo.continuum.io/miniconda/Miniconda-latest-Linux-x86_64.sh
bash Miniconda-latest-Linux-x86_64.sh -b -p ~/install/bcbio-vm/anaconda
~/install/bcbio-vm/anaconda/bin/conda update --yes conda
~/install/bcbio-vm/anaconda/bin/conda install --yes -c https://conda.binstar.org/bcbio bcbio-nextgen-vm
ln -s ~/install/bcbio-vm/anaconda/bin/bcbio_vm.py /usr/local/bin/bcbio_vm.py
