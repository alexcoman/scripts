#!/bin/bash
set -e

function load_config() {
	CONFIG_PATH='./default.conf'
	CONFIG_SYNTAX="^\s*#|^\s*$|^[a-zA-Z_]+='[^']*'$"

	if egrep -q -v "${CONFIG_SYNTAX}" "$CONFIG_PATH"; then
	  echo "Error parsing config file ${CONFIG_PATH}." >&2
	  echo "The following lines in the configfile do not fit the syntax:" >&2
	  egrep -vn "${CONFIG_SYNTAX}" "$CONFIG_PATH"
	  exit 5
	fi
	source "${CONFIG_PATH}"
}

function install_bcbio() {
	cd
	if [ -d "$BCBIOVM_PATH" ]; then
		echo "Removing the old version of bcbio-nextgen-vm."
		sudo rm -rf bcbio-nextgen-vm &> /dev/null
	fi
	echo "Cloning the bcbio-nextgen-vm project."
	git clone -b "$BCBIOVM_BRANCH" "$BCBIOVM_REPO" &> /dev/null

	cd "$BCBIOVM_PATH"
	echo "Installing bcbio-nextgen-vm requirements."
	sudo pip install -r requirements.txt &> /dev/null
	echo "Installing the bcbio-nextgen-vm project."
	sudo python setup.py install &> /dev/null
}

load_config
install_bcbio