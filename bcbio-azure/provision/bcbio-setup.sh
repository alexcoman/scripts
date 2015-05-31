#!/bin/bash
set -e

function install_bcbio() {
	cd /
	if [ ! -d "bcbio-nextgen-vm" ]; then
		git clone -b $BRANCH $REPO;
	fi
	cd "bcbio-nextgen-vm"
	git pull
	sudo pip install requirements.txt
	sudo python setup.py install
}