#!/bin/bash
set -e

# Settings
COUNTRY=""          # Country Name (2 letter code)
STATE=""            # State or Province Name (full name)
LOCALITY=""         # Locality Name (eg, city)
ORGANIZATION=""     # Organization Name (eg, company)
NAME=""             # Common Name (e.g. server FQDN or YOUR name)
EMAIL=""            # Email Address

CERT_DIR="/home/vagrant/.ssh/"
SITE_PACKAGES="/home/vagrant/.venv/ec-azure-experimental/lib/python2.7/site-packages"
AZURE_EXPERIMENTAL="/home/vagrant/elasticluster/azure-experimental"

function prologue() {
    if [ ! -d "$CERT_DIR" ]; then
      echo "Create $CERT_DIR"
      mkdir $CERT_DIR
    fi
}

function install_elasticluster() {
    echo "Creating the ec-azure-experimental virtualenv"
    virtualenv --python=/usr/bin/python2.7 /home/vagrant/.venv/ec-azure-experimental

    echo "Activating .venv/ec-azure-experimental"
    source /home/vagrant/.venv/ec-azure-experimental/bin/activate

    echo "Installing elasticluster requirements"
    pip install -q pip --upgrade > /dev/null
    pip install -q ansible==1.7.2 azure google-api-python-client &> /dev/null

    echo "Cloning elasticluster"
    git clone https://github.com/bobd00/elasticluster

    echo "Installing elasticluster"
    cd /home/vagrant/elasticluster
    python setup.py install -q &> /dev/null
}

function patch_libs() {
    git checkout azure-experimental

    echo "Patching azure.servicemanagement.__init__"
    sed -i 's/if configuration.public_ips:/if False:/g' "$SITE_PACKAGES/azure/servicemanagement/__init__.py"

    echo "Patching ansible.runner.__init__"
    cp "$AZURE_EXPERIMENTAL/ansible/runner/__init__.py" "$SITE_PACKAGES/ansible/runner/__init__.py"

    git checkout master
}

function management_certificate() {
    echo "Generate the management certificate for Azure"
    subject=""

    if [ $COUNTRY ]; then
        subject+="/C=$COUNTRY"
    fi
    if [ $STATE ]; then
        subject+="/ST=$STATE"
    fi
    if [ $ORGANIZATION ]; then
        subject+="/O=$ORGANIZATION"
    fi
    if [ $CNAME ]; then
        subject+="/CN=$NAME"
    fi
    if [ $EMAIL ]; then
        subject+="/emailAddress=$EMAIL"
    fi

    if [ ! subject ]; then
        echo "Failed to generate the management certificate."
        return -1
    fi
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /home/vagrant/.ssh/managementCert.pem \
        -out /home/vagrant/.ssh/managementCert.pem \
        -subj "$subject" &> /dev/null
    openssl x509 -outform der \
        -in /home/vagrant/.ssh/managementCert.pem \
        -out /home/vagrant/.ssh/managementCert.cer > /dev/null
}

function epilogue() {
    echo "Done!"
}

# TODO(alexandrucoman): Generate the client ssh keys
# TODO(alexandrucoman): Generate the config file

prologue
install_elasticluster
patch_libs
management_certificate
epilogue
