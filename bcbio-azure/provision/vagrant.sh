#!/bin/bash
set -e

echo "Cleanup the environment"
apt-get remove -y python-six &> /dev/null 

echo "Update the system."
apt-get update -y &> /dev/null
apt-get upgrade -y &> /dev/null

echo "Installing pip."
wget https://bootstrap.pypa.io/get-pip.py &> /dev/null
chmod +x get-pip.py
python get-pip.py &> /dev/null
rm get-pip.py
pip install setuptools --upgrade &> /dev/null
pip install pip --upgrade &> /dev/null

echo "Installing required packages."
apt-get install -qqy htop git &> /dev/null
apt-get install -qqy build-essential python-dev &> /dev/null

echo "Installing requirements for openssl."
apt-get install -qqy libssl-dev libffi-dev &> /dev/null

echo "Installing requirements for pycurl."
apt-get install -qqy libcurl4-openssl-dev &> /dev/null

echo "Installing requirements for lxml."
apt-get install -qqy libxml2-dev libxslt1-dev &> /dev/null

echo "Installing requirements for matplotlib."
apt-get install -qqy libxft-dev libpng-dev libfreetype6-dev &> /dev/null

echo "Installing requirements for scipy."
apt-get install -qqy liblapack-dev gfortran &> /dev/null
apt-get install -qqy libgmp-dev libmpfr-dev &> /dev/null
apt-get install -qqy libblas-dev libblas3gf &> /dev/null

echo "Installing requirements for matplotlib"
apt-get install -qqy inkscape libav-tools gdb mencoder dvipng &> /dev/null
apt-get install -qqy graphviz &> /dev/null

echo "Installing requirements for pysam"
apt-get install -qqy gcc g++ zlib1g-dev libbz2-dev libpng12-dev &> /dev/null
apt-get install -qqy libatlas-dev libpq-dev r-base-dev libreadline-dev &> /dev/null
apt-get install -qqy libmysqlclient-dev libboost-dev libsqlite3-dev &> /dev/null

echo "Installing azure client."
apt-get install -y nodejs-legacy npm &> /dev/null
npm install -gq azure-cli &> /dev/null
