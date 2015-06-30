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
    echo "Reinstall python-setuptools"
    sudo apt-get install -y python-setuptools &> /dev/null
    cd
    if [ -d "$BCBIOVM_PATH" ]; then
        if sudo pip freeze | grep bcbio-nextgen-vm
        then
            echo "Removing the old version of bcbio-nextgen-vm."
            sudo pip uninstall --yes bcbio-nextgen-vm &> /dev/null
        fi
        sudo rm -rf bcbio-nextgen-vm &> /dev/null
    fi
    echo "Cloning the bcbio-nextgen-vm project."
    git clone -b "$BCBIOVM_BRANCH" "$BCBIOVM_REPO" &> /dev/null

    cd "$BCBIOVM_PATH"
    echo "Replace the elasticluster version from requirements.txt"
    sed -i -e "s/git+git:\/\/github.com\/chapmanb\/elasticluster.git@bcbio/azure-elasticluster/g" requirements.txt

    echo "Installing bcbio-nextgen-vm requirements."
    sudo pip install -r requirements.txt --upgrade --cache-dir "$PIP_CACHE" &> /dev/null

    echo "Installing pybedtools in order to avoid MemoryError."
    sudo pip install "pybedtools>=0.6.8" &> /dev/null

    echo "Installing the bcbio-nextgen-vm project."
    sudo python setup.py install &> /dev/null
}

function install_elasticluster() {
    pip_packages=$(sudo pip freeze)
    if grep -q azure-elasticluster <<<"$pip_packages"; then
        echo "Remove the current version of elasticluster."
        sudo pip uninstall --yes azure-elasticluster &> /dev/null
    elif grep -q elasticluster <<<"$pip_packages"; then
        echo "Remove the current version of elasticluster."
        sudo pip uninstall --yes elasticluster &> /dev/null
    fi
    echo "Install the bcbio version of elasticluster."
    sudo pip install git+https://github.com/chapmanb/elasticluster@bcbio &> /dev/null
}

function management_cert() {
    generate_cert=false;
    if [ ! -d "$SHARE_DIR" ]; then
        mkdir -p "$SHARE_DIR"
    fi

    for file in "managementCert.cer" "managementCert.pem"
    do
        if [ -f "$SHARE_DIR/$file" ]; then
            echo "Copy $file from $SHARE_DIR."
            cp "$SHARE_DIR/$file" "$HOME/.ssh/$file"
        else
            generate_cert=true;
        fi
    done

    if $generate_cert; then
        echo "Generate new management certificate."
        bcbio_vm.py azure prepare management-cert &> /dev/null
        for file in "managementCert.cer" "managementCert.pem"
        do
            echo "Copy $file to $SHARE_DIR."
            cp "$HOME/.ssh/$file" "$SHARE_DIR/$file"
        done
    fi
}

function ssh_keys() {
    if [ ! -f ~/.ssh/managementCert.key ]; then
        echo "Generate new SSH keys."
        bcbio_vm.py azure prepare pkey &> /dev/null
    fi
}

function elasticluster_config() {
    ec_dirname="$(dirname $EC_CONFIG)"
    if [ ! -d "$ec_dirname" ]; then
        echo "Create $ec_dirname directory"
        mkdir -p "$ec_dirname"
    fi

    if [ -f "$SHARE_DIR/azure.config" ]; then
        if [ -f "$EC_CONFIG" ]; then
            echo "The $EC_CONFIG already exists."
            share_file=$(md5sum "$SHARE_DIR/azure.config" | cut -f 1 -d " ")
            local_file=$(md5sum "$EC_CONFIG" | cut -f 1 -d " ")
            if [ ! "$share_file" = "$local_file" ]; then
                echo "Make a copy of the current elasticluster config."
                cp -i "$EC_CONFIG" "$EC_CONFIG.backup"
                cp -i "$SHARE_DIR/azure.config" "$EC_CONFIG"
            else
                echo "Vagrant is using the last version of elasticluster config."
            fi
        else
            echo "Use the elasticluster config file from $SHARE_DIR"
            cp -i "$SHARE_DIR/azure.config" "$EC_CONFIG"
        fi
    else
        echo "Write the elasticluster config file."
        bcbio_vm.py azure prepare ec-config --econfig "$EC_CONFIG" &> /dev/null
        echo "Copy the elasticluster config file to $SHARE_DIR"
        cp "$EC_CONFIG" "$SHARE_DIR/azure.config"
    fi
}

function enforce_ansible_version() {
    echo "Enforce ansible version 1.7.2"
    pip_packages=$(sudo pip freeze)
    if grep -q ansible <<<"$pip_packages"; then
        echo "Remove the current version of ansible."
        sudo pip uninstall --yes ansible &> /dev/null
    fi
    sudo pip install --no-use-wheel ansible==1.7.2 &> /dev/null
}

function update_permissions() {
    echo "Change permisions for ~/.ssh directory."
    chmod 700 "$HOME/.ssh/"

    echo "Change permisions for managementCert"
    chmod 600 "$HOME/.ssh/managementCert.pem"
    chmod 600 "$HOME/.ssh/managementCert.key"

    if [ ! -d "$HOME/.ansible/cp" ]; then
        mkdir -p "$HOME/.ansible/cp"
    fi
    echo "Change permisions for ~/.ansible"
    chmod --recursive 755 "$HOME/.ansible"
}

load_config
pip_cache
install_bcbio
install_elasticluster
enforce_ansible_version
management_cert
ssh_keys
update_permissions
elasticluster_config
