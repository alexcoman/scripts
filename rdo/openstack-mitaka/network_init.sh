#!/bin/bash

#ovs-vsctl add-port br-ex "device-name"
ifconfig "device-name" 0 # Change the device-name accordingly to the interface present
						 # in /etc/sysconfig/network-scripts/ifcfg-...
ifconfig br-ex 192.168.133.141/24 up # Set up the IP accordingly to the hostname IP
route add default gw 192.168.133.1 br-ex

