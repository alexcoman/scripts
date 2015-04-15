#!/bin/bash
set -e

# Settings
COUNTRY=""          # Country Name (2 letter code)
STATE=""            # State or Province Name (full name)
LOCALITY=""         # Locality Name (eg, city)
ORGANIZATION=""     # Organization Name (eg, company)
NAME=""             # Common Name (e.g. server FQDN or YOUR name)
EMAIL=""            # Email Address

SUBSCRIPTION=""
LOCATION="East US"
SERVICE_NAME="ec-azure-service"
STORAGE_ACCOUNT="ec-azure-storage"
DEPLOYMENT="ec-azure-deployment"
IMAGE_ID="b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-12_04_2-LTS-amd64-server-20121218-en-us-30GB"
FRONTEND_NODES="1"
COMPUTE_NODES="6"
FLAVOR="Small"

MANAGEMENT_CER="managementCert.cer"
MANAGEMENT_PEM="managementCert.pem"
CLIENT_KEY="azureClient.key"
CLIENT_RSA_KEY="azureClientRSA.key"
CLIENT_PEM="azureClient.pem"

CERT_DIR="/home/vagrant/.ssh"
SITE_PACKAGES="/home/vagrant/.venv/ec-azure-experimental/lib/python2.7/site-packages"
AZURE_EXPERIMENTAL="/home/vagrant/elasticluster/azure-experimental"

function prologue() {
    if [ ! -d "$CERT_DIR" ]; then
      echo "Create $CERT_DIR"
      mkdir -p $CERT_DIR
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

function get_subject() {
    local subject=""

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
    echo "$subject"
}

function management_certificate() {
    echo "Generating the management certificate for Azure"
    
    local subject=$(get_subject)
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

function client_ssh_keys() {
    echo "Generating the client ssh keys."

    local subject=$(get_subject)
    if [ ! subject ]; then
        echo "Failed to generate the management certificate."
        return -1
    fi

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ~/.ssh/azureClient.key \
        -out ~/.ssh/azureClient.pem \
        -subj "$subject" &> /dev/null
    openssl rsa \
        -in ~/.ssh/azureClient.key \
        -out ~/.ssh/azureClientRSA.key &> /dev/null
}

function create_config(){
    echo "Creating elasticluster config"
    local template="#Elasticluster - Azure experimental
[cloud/azure-cloud]
provider=azure
subscription_id=$SUBSCRIPTION
certificate=$CERT_DIR/$MANAGEMENT_PEM

[login/azure-login]
image_user=ecazure
image_user_sudo=root
image_sudo=True

# keypair used to run stuff on the nodes.
user_key_name=$CLIENT_KEY
user_key_private=$CERT_DIR/$CLIENT_RSA_KEY
user_key_public=$CERT_DIR/$CLIENT_PEM

[setup/ansible-gridengine-azure]
provider=ansible
frontend_groups=gridengine_master
compute_groups=gridengine_clients

[cluster/azure-gridengine]
cloud=azure-cloud
login=azure-login
setup_provider=ansible-gridengine-azure
cloud_service_name=$SERVICE_NAME
location=$LOCATION
frontend_nodes=$FRONTEND_NODES
compute_nodes=$COMPUTE_NODES
ssh_to=frontend
image_id=$IMAGE_ID
flavor=$FLAVOR
storage_account_name=$STORAGE_ACCOUNT
security_group=default
deployment_name=$DEPLOYMENT
global_var_ansible_ssh_host_key_dsa_public=''"
    echo "$template" > ~/azure.conf
}

function epilogue() {
    echo "Done!"
}

prologue
install_elasticluster
patch_libs
management_certificate
client_ssh_keys
create_config
epilogue
