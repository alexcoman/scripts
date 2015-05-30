#!/bin/bash
set -e

echo "Update the system"
apt-get update -qy > /dev/null
apt-get upgrade -qy > /dev/null

echo "Installing required packages"
apt-get install -qy git screen vim &> /dev/null
apt-get install -qy build-essential python-dev python-pip &> /dev/null
apt-get install -qy libssl-dev libffi-dev nodejs-legacy &> /dev/null
apt-get install libxml2-dev libxslt1-dev &> /dev/null
apt-get install -qy npm &> /dev/null

npm install -gq azure-cli &> /dev/null
