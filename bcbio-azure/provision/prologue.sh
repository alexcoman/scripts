#!/bin/bash
echo "Installing do2unix"
sudo apt-get install dos2unix &> /dev/null

echo "Change the line ending for the files from /vagrant"
dos2unix /vagrant/provision/bcbio-setup.sh
dos2unix /vagrant/provision/vagrant.sh
dos2unix /vagrant/provision/default.conf