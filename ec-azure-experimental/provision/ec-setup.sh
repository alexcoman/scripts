#!/bin/bash
set -e

SITE_PACKAGES="/home/vagrant/.venv/ec-azure-experimental/lib/python2.7/site-packages"
AZURE_EXPERIMENTAL="/home/vagrant/elasticluster/azure-experimental"

echo "Creating the ec-azure-experimental virtualenv"
virtualenv --python=/usr/bin/python2.7 /home/vagrant/.venv/ec-azure-experimental

echo "Activating .venv/ec-azure-experimental"
source /home/vagrant/.venv/ec-azure-experimental/bin/activate

echo "Installing elasticluster requirements"
pip install pip --upgrade > /dev/null
pip install ansible==1.7.2 azure google-api-python-client &> /dev/null

echo "Cloning elasticluster"
git clone https://github.com/bobd00/elasticluster &> /dev/null

echo "Installing elasticluster"
cd elasticluster
python setup.py install &> /dev/null

echo "Patching ansible.runner.__init__"
git checkout azure-experimental
cp "$AZURE_EXPERIMENTAL/ansible/runner/__init__.py" "$SITE_PACKAGES/ansible/runner/__init__.py"
git checkout master

echo "Patching azure.servicemanagement.__init__"
sed -i 's/if configuration.public_ips:/if False:/g' "$SITE_PACKAGES/azure/servicemanagement/__init__.py"

# TODO(alexandrucoman): Generate the management certificate for Azure
# TODO(alexandrucoman): Generate the client ssh keys
# TODO(alexandrucoman): Generate the config file

echo "Done!"
