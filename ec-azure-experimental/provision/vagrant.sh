#!/bin/bash
set -e

echo "Update the system"
apt-get update -qy > /dev/null
apt-get upgrade -qy > /dev/null

echo "Installing requirede packages"
apt-get install -y build-essential python-dev git python-pip libssl-dev libffi-dev nodejs-legacy npm > /dev/null
npm install -g azure-cli > /dev/null
pip install virtualenv &> /dev/null
