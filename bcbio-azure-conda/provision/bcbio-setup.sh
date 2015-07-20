#!/bin/bash
set -e
PATH="$HOME/miniconda/bin:$PATH"

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


function install_bcbio() {
    echo "Installing bcbio-nextgen-vm"
    conda install --yes -c "$CHANNEL" bcbio-nextgen &> /dev/null
    conda install --yes -c "$CHANNEL" bcbio-nextgen-vm &> /dev/null
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
                cp "$EC_CONFIG" "$EC_CONFIG.backup"
                cp "$SHARE_DIR/azure.config" "$EC_CONFIG"
            else
                echo "Vagrant is using the last version of elasticluster config."
            fi
        else
            echo "Use the elasticluster config file from $SHARE_DIR"
            cp "$SHARE_DIR/azure.config" "$EC_CONFIG"
        fi
    else
        echo "Write the elasticluster config file."
        bcbio_vm.py azure prepare ec-config --econfig "$EC_CONFIG" &> /dev/null
        echo "Copy the elasticluster config file to $SHARE_DIR"
        cp "$EC_CONFIG" "$SHARE_DIR/azure.config"
    fi
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
install_bcbio
management_cert
ssh_keys
update_permissions
elasticluster_config
