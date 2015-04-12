#!/bin/bash
set -e

echo "Update the system"
apt-get update -qy > /dev/null
apt-get upgrade -qy > /dev/null

echo "Installing required packages"
apt-get install -qy build-essential python-dev git python-pip libssl-dev libffi-dev nodejs-legacy npm &> /dev/null
npm install -gq azure-cli &> /dev/null
pip install virtualenv &> /dev/null
