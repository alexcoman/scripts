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
    NETID1=$(neutron net-create private --provider:network_type flat --provider:physical_network physnet1 | awk '{if (NR == 6) {print $4}}');
    echo "[i] Private network id: $NETID1";
    
    # Creathe the private subnetwork
    SUBNETID1=$(neutron subnet-create private 10.100.0.0/24 --gateway 10.100.0.2 --dns_nameservers list=true 8.8.8.8 | awk '{if (NR == 11) {print $4}}');
    
    # Create the router
    ROUTERID1=$(neutron router-create router1 | awk '{if (NR == 9) {print $4}}');
    
    # Attach the private subnetwork to the router
    neutron router-interface-add $ROUTERID1 $SUBNETID1
    
    # Create the public network
    EXTNETID1=$(neutron net-create public --router:external | awk '{if (NR == 6) {print $4}}');
    
    # Create the public subnetwork
    neutron subnet-create public --allocation-pool start=10.0.2.66,end=10.0.2.126 --gateway 10.0.2.65 10.0.2.64/26 --disable-dhcp    
    
    # Attach the public network to the router
    neutron router-gateway-set $ROUTERID1 $EXTNETID1
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
