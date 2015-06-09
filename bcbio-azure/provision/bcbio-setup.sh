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
		if sudo pip freeze | grep bcbio-nextgen-vm
		then
			echo "Reinstall python-setuptools"
			sudo apt-get install python-setuptools &> /dev/null
			echo "Removing the old version of bcbio-nextgen-vm."
			sudo pip uninstall --yes bcbio-nextgen-vm &> /dev/null
		fi
		sudo rm -rf bcbio-nextgen-vm &> /dev/null
	fi
	echo "Cloning the bcbio-nextgen-vm project."
	git clone -b "$BCBIOVM_BRANCH" "$BCBIOVM_REPO" &> /dev/null

	cd "$BCBIOVM_PATH"
	echo "Installing bcbio-nextgen-vm requirements."
	sudo pip install -r requirements.txt --upgrade --cache-dir "$PIP_CACHE" &> /dev/null
	echo "Installing pybedtools in order to avoid MemoryError."
	sudo pip install "pybedtools>=0.6.8" &> /dev/null
	echo "Installing the bcbio-nextgen-vm project."
	sudo python setup.py install &> /dev/null
}

function install_ansible() {
	pip_packages=$(sudo pip freeze)
	if grep -q azure-ansible <<<$pip_packages; then
		echo "Remove the current version of azure-ansible."
		sudo pip uninstall --yes azure-ansible &> /dev/null
	elif grep -q ansible <<<"$pip_packages"; then
		echo "Remove the current version of ansible."
		sudo pip uninstall --yes ansible &> /dev/null
	fi
	echo "Install azure-ansible."
	sudo pip install --pre azure-ansible &> /dev/null
}

function install_elasticluster() {
	pip_packages=$(sudo pip freeze)
	if grep -q azure-elasticluster <<<$pip_packages; then
		echo "Remove the current version of elasticluster."
		sudo pip uninstall --yes azure-elasticluster &> /dev/null
	elif grep -q elasticluster <<<"$pip_packages"; then
		echo "Remove the current version of elasticluster."
		sudo pip uninstall --yes elasticluster &> /dev/null
	fi
	echo "Install azure-elasticluster."
	sudo pip install --pre azure-elasticluster &> /dev/null
}


load_config
pip_cache
install_bcbio
install_ansible
install_elasticluster
