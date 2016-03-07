#!/bin/bash

function delete_openstack_networks() {
    # ######################################## #
    # Remove the current network configuration #
    # ######################################## #

    # Remove the private subnet from the router
    neutron router-interface-delete router1 private-subnet

    # Remove the public network from the router
    neutron router-gateway-clear router1

    # Delete the router
    neutron router-delete router1

    # Delete the private network
    neutron net-delete private

    # Delete the public network
    neutron net-delete public
}

function create_openstack_networks() {
    # ############################ #
    # Setup the openstack networks #
    # ############################ #

    # Create the private network
    NET_ID=$(neutron net-create private --provider:network_type flat --provider:physical_network physnet1 | awk '{if (NR == 6) {print $4}}');
    echo "[i] Private network id: $NET_ID";

    # Creathe the private subnetwork
    SUBNET_ID=$(neutron subnet-create private 10.100.0.0/24 --gateway 10.100.0.2 --dns_nameservers list=true 8.8.8.8 | awk '{if (NR == 12) {print $4}}');
    echo "[i] Private sub-network id: $SUBNET_ID";

    # Create the router
    ROUTER_ID=$(neutron router-create router1 | awk '{if (NR == 9) {print $4}}');
    echo "[i] Router id: $ROUTER_ID";

    # Attach the private subnetwork to the router
    neutron router-interface-add $ROUTER_ID $SUBNET_ID

    # Create the public network
    EXTNET_ID=$(neutron net-create public --router:external | awk '{if (NR == 6) {print $4}}');
    echo "[i] Public sub-network id: $EXTNET_ID";

    # Create the public subnetwork
    SUBNET_ID=$(neutron subnet-create public 10.0.2.0/24 --gateway 10.0.2.65 --allocation-pool start=10.0.2.66,end=10.0.2.126 --disable-dhcp);
    echo "[i] Public sub-network id: $SUBNET_ID";

    # Attach the public network to the router
    neutron router-gateway-set $ROUTER_ID $EXTNET_ID
}

function security_groups() {
    # ############################ #
    # Update Security Groups rules #
    # ############################ #

    # Enable ping
    nova secgroup-add-rule default ICMP 8 8 0.0.0.0/0

    # Enable SSH
    nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

    # Enable RDP
    nova secgroup-add-rule default tcp 3389 3389 0.0.0.0/0
}

delete_openstack_networks
create_openstack_networks
security_groups
