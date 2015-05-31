#!/bin/bash
set -e

echo "Update the system."
apt-get update -y &> /dev/null
apt-get upgrade -y &> /dev/null

echo "Installing required packages."
apt-get install -y git screen vim &> /dev/null
apt-get install -y build-essential python-dev python-pip &> /dev/null

echo "Installing requirements for openssl."
apt-get install -y libssl-dev libffi-dev &> /dev/null

echo "Installing requirements for pycurl."
apt-get install -y libcurl4-openssl-dev &> /dev/null

echo "Installing requirements for lxml."
apt-get install -y libxml2-dev libxslt1-dev &> /dev/null

echo "Installing requirements for matplotlib."
apt-get install -y libxft-dev libpng-dev libfreetype6-dev &> /dev/null

echo "Installing requirements for scipy."
apt-get install -y liblapack-dev gfortran &> /dev/null
apt-get install -y libgmp-dev libmpfr-dev &> /dev/null
apt-get install -y libblas-dev libblas3gf &> /dev/null

echo "Installing requirements for matplotlib"
apt-get install -y inkscape libav-tools gdb mencoder dvipng &> /dev/null
apt-get install -y graphviz &> /dev/null

echo "Installing requirements for pysam"
apt-get install -y gcc g++ zlib1g-dev libbz2-dev libpng12-dev &> /dev/null
apt-get install -y libatlas-dev libpq-dev r-base-dev libreadline-dev &> /dev/null
apt-get install -y libmysqlclient-dev libboost-dev libsqlite3-dev &> /dev/null

echo "Installing requirements for biopython"
apt-get install -y clustalo &> /dev/null
apt-get install -y muscle mafft probcons wise emboss &> /dev/null
apt-get install -y samtools bwa &> /dev/null

echo "Installing azure client."
apt-get install -y nodejs-legacy npm &> /dev/null
npm install -gq azure-cli &> /dev/null

echo "Upgrading pip."
pip install pip --upgrade &> /dev/null
