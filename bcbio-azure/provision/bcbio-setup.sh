#!/bin/bash
set -e

function load_config() {
	CONFIG_PATH='/vagrant/provision/default.conf'
	CONFIG_SYNTAX="^\s*#|^\s*$|^[a-zA-Z_]+='[^']*'$"

	if egrep -q -v "${CONFIG_SYNTAX}" "$CONFIG_PATH"; then
	  echo "Error parsing config file ${CONFIG_PATH}." >&2
	  echo "The following lines in the configfile do not fit the syntax:" >&2
	  egrep -vn "${CONFIG_SYNTAX}" "$CONFIG_PATH"
	  exit 5
	fi
	source "${CONFIG_PATH}"
}

function pip_cache() {
	if [ ! -d "$PIP_CACHE" ]; then
		sudo mkdir -p "$PIP_CACHE"
	fi
}

function install_bcbio() {
	cd
	if [ -d "$BCBIOVM_PATH" ]; then
		echo "Removing the old version of bcbio-nextgen-vm."
		sudo pip uninstall bcbiovm
		sudo rm -rf bcbio-nextgen-vm &> /dev/null
	fi
	echo "Cloning the bcbio-nextgen-vm project."
	git clone -b "$BCBIOVM_BRANCH" "$BCBIOVM_REPO" &> /dev/null

	cd "$BCBIOVM_PATH"
	echo "Installing bcbio-nextgen-vm requirements."
	sudo pip install -r requirements.txt --upgrade --cache-dir "$PIP_CACHE" &> /dev/null
	echo "Installing pybedtools in order to avoid MemoryError."
	sudo pip install pybedtools>=0.6.8 &> /dev/null
	echo "Installing the bcbio-nextgen-vm project."
	sudo python setup.py install &> /dev/null
}

function install_ansible() {
	echo "Remove the current version of ansible."
	sudo pip uninstall ansible &> /dev/null
	echo "Install azure-ansible."
	sudo pip install --pre azure-ansible &> /dev/null
}

function install_elasticluster() {
	echo "Remove the current version of elasticluster."
	sudo pip uninstall elasticluster &> /dev/null
	echo "Install azure-elasticluster."
	sudo pip install --pre azure-elasticluster &> /dev/null
}


load_config
pip_cache
install_bcbio
install_ansible
install_elasticluster
