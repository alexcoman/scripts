#Deploy OpenStack Kilo with DevStack

##Step by step tutorial for deploying OpenStack

### Table of Contents

- [Create the Virtual Machine](#create-the-virtual-machine)
- [Setting up the system](#setting-up-the-system)
    - [Edit network Interfaces](#edit-network-interfaces)
    - [Add OVS Bridges](#add-ovs-bridges)
- [Setting up the OpenStack environment](#setting-up-the-openstack-environment)
    - [Clone DevStack](#clone-devstack)
    - [Change local.conf](#change-local-conf)
    - [Edit ~/.shellrc](#edit-shellrc)
    - [Run stack.sh](#run-stack-sh)
    - [Prepare DevStack](#prepare-devstack)
    - [Port forwarding](#port-forwarding)
- [Troubleshooting](#troubleshooting)
    - [OpenStack role list raises unrecognized arguments: –group](#openstack-role-list-raises-unrecognized-arguments-group)


##Create the Virtual Machine
- Processors:
    - Number of processors: 2
    - Number of cores per processor 1
- Memory: 4GB RAM (Recommended)
- HDD - SATA - Minimum 20 GB (Recommended *Preallocated*)
- Network:
    - Network Adapter 1:  **NAT**
    - Network Adapter 2:  **Host Only**
    - Network Adapter 3:  **NAT**
- Operating system - **Ubuntu Server 14.04** (Recommended) 

Note: The Hypervisor used for this example is **VirtualBox**

##Setting up the system

```bash
# Update the apt-get
~ $ sudo apt-get update

# Update the system
~ $ sudo apt-get upgrade

# Install the required tools
~ $ sudo apt-get install -y git vim openssh-server openvswitch-switch ethtool
```


###Edit network Interfaces

```bash
~ $ sudo vim /etc/network/interfaces
```

**IMPORTANT:** This is a template. Please use your own settings.

```vim
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
    address 10.0.2.15
    netmask 255.255.255.0
    gateway 10.0.2.2
    broadcast 10.0.2.255
    dns-nameserver 8.8.8.8 8.8.4.4

# The management interface
auto eth1
iface eth1 inet manual
    up ip link set eth1 up
    up ip link set eth1 promisc on
    down ip link set eth1 promisc off
    down ip link set eth1 down

# The public interface
auto eth2
iface eth2 inet manual
    up ip link set eth2 up
    down ip link set eth2 down
```

**IMPORTANT:** After you edit ```/etc/network/interfaces``` the ```network service``` should be restarted.

```bash
# Restart the networking service
~ $ sudo service networking restart

# Disable the firewall
~ $ sudo ufw disable

# Disable rx/tx vlan offloading
~ $ sudo ethtool -K eth1 txvlan off rxvlan off
```

**Note**: If the above command fails a reboot will be required.


### Add OVS Bridges

```bash
~ $ sudo ovs-vsctl add-br br-eth1
~ $ sudo ovs-vsctl add-port br-eth1 eth1

~ $ sudo ovs-vsctl add-br br-ex
~ $ sudo ovs-vsctl add-port br-ex eth2
```

##Setting up the OpenStack environment

###Clone DevStack

```bash
~ $ cd
~ $ git clone https://github.com/openstack-dev/devstack.git
~ $ cd devstack
~ $ git checkout stable/kilo
```

###Create the local.conf

```bash
~ $ sudo vim ~/devstack/local.conf
```

**IMPORTANT:** The following config file is a template. Please use your own settings.

We will start with general information related to our deployment.

```ini
[[local|localrc]]
HOST_IP=10.0.2.15
DEVSTACK_BRANCH=stable/kilo
DEVSTACK_PASSWORD=Passw0rd

# Change the following passwords
DATABASE_PASSWORD=$DEVSTACK_PASSWORD
RABBIT_PASSWORD=$DEVSTACK_PASSWORD
SERVICE_TOKEN=$DEVSTACK_PASSWORD
SERVICE_PASSWORD=$DEVSTACK_PASSWORD
ADMIN_PASSWORD=$DEVSTACK_PASSWORD

KEYSTONE_BRANCH=$DEVSTACK_BRANCH
NOVA_BRANCH=$DEVSTACK_BRANCH
NEUTRON_BRANCH=$DEVSTACK_BRANCH
SWIFT_BRANCH=$DEVSTACK_BRANCH
GLANCE_BRANCH=$DEVSTACK_BRANCH
CINDER_BRANCH=$DEVSTACK_BRANCH
HEAT_BRANCH=$DEVSTACK_BRANCH
TROVE_BRANCH=$DEVSTACK_BRANCH
HORIZON_BRANCH=$DEVSTACK_BRANCH
TROVE_BRANCH=$DEVSTACK_BRANCH
REQUIREMENTS_BRANCH=$DEVSTACK_BRANCH

IMAGE_URLS+=",https://people.debian.org/~aurel32/qemu/amd64/debian_wheezy_amd64_standard.qcow2"

Q_PLUGIN=ml2
Q_ML2_PLUGIN_MECHANISM_DRIVERS=openvswitch
Q_ML2_TENANT_NETWORK_TYPE=vlan

PHYSICAL_NETWORK=physnet1
OVS_PHYSICAL_BRIDGE=br-eth1
OVS_BRIDGE_MAPPINGS=physnet1:br-eth1

OVS_ENABLE_TUNNELING=False
ENABLE_TENANT_VLANS=True
TENANT_VLAN_RANGE=500:2000

GUEST_INTERFACE_DEFAULT=eth1
PUBLIC_INTERFACE_DEFAULT=eth2

FLOATING_RANGE=10.0.2.64/26
PUBLIC_NETWORK_GATEWAY=10.0.2.65
Q_FLOATING_ALLOCATION_POOL=start=10.0.2.66,end=10.0.2.126

FIXED_NETWORK_SIZE=256
FIXED_RANGE=10.100.0.0/24
NETWORK_GATEWAY=10.100.0.2

CINDER_SECURE_DELETE=False
VOLUME_BACKING_FILE_SIZE=50000M

LIVE_MIGRATION_AVAILABLE=False
USE_BLOCK_MIGRATION_FOR_LIVE_MIGRATION=False

LIBVIRT_TYPE=kvm
API_RATE_LIMIT=False

SCREEN_LOGDIR=/opt/stack/logs/screen
VERBOSE=True
LOG_COLOR=False
```

Now we will specify all the services that should be installed.

```bash
#Services to be started

# Requirements
enable_service rabbit
enable_service mysql

# Keystone
enable_service key

# Nova
enable_service n-api
enable_service n-crt
enable_service n-obj
enable_service n-cond
enable_service n-sch
enable_service n-cauth
enable_service n-novnc
enable_service n-cpu

# Neutron
enable_service neutron
enable_service q-svc
enable_service q-agt
enable_service q-dhcp
enable_service q-l3
enable_service q-meta
enable_service q-lbaas
enable_service q-fwaas
enable_service q-metering
enable_service q-vpn

# Horizon
enable_service horizon

# Glance
enable_service g-api
enable_service g-reg

# Cinder
enable_service cinder
enable_service c-api
enable_service c-vol
enable_service c-sch
enable_service c-bak

# Services that should not be installed
disable_service n-net
disable_service s-proxy
disable_service s-object
disable_service s-container
disable_service s-account
disable_service heat
disable_service h-api
disable_service h-api-cfn
disable_service h-api-cw
disable_service h-eng
disable_service ceilometer-acompute
disable_service ceilometer-acentral
disable_service ceilometer-collector
disable_service ceilometer-api
disable_service tempest
```

And finally we will setup the post-config section (it will run after the layer 2 services are configured and before they are started).

```ini
[[post-config|$NEUTRON_CONF]]
[database]
min_pool_size = 5
max_pool_size = 50
max_overflow = 50
```

More information regarding local.conf can be found on [Devstack configuration](http://docs.openstack.org/developer/devstack/configuration.html).


###Edit ~/.bashrc

```bash
~ $ vim ~/.bashrc
```

Add this lines at the end of file.

```bash
export OS_USERNAME=admin
export OS_PASSWORD=Passw0rd
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://127.0.0.1:5000/v2.0
```

And after that run the following command:
 
```bash
~ $ source ~/.bashrc
```

###Run stack.sh

```bash
~ $ cd ~/devstack
~ $ ./stack.sh
```

**IMPORTANT:** If the scripts doesn't end properly or something else goes wrong, please unstack first using ```./unstack.sh``` script.


###Prepare DevStack

```bash
#!/bin/shell
KEY="$HOME/.ssh/devstack_key"

# I. Public / Private Keys
if [ ! -f "$KEY" ];
then
    ssh-keygen -f "$KEY" -t rsa -N ''
fi
nova keypair-add userkey --pub_key "$KEY.pub"

# [Security Groups]

# Enable ping
nova secgroup-add-rule default ICMP -1 -1 0.0.0.0/0

# Enable SSH
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

# Enable RDP
nova secgroup-add-rule default tcp 3389 3389 0.0.0.0/0

# Update iptables rules
sudo iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
sudo iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited
sudo service iptables save
```

###Port forwarding
In order to access services from the DevStack virtual machine from the host machine we need to forward the to host.

For each used port we need to run one of the following commands:

```bash
# If the virtual machine is in power off state.
VBoxManage --modifyvm DevStack [--natpf<1-N> [<rulename>],tcp|udp,[<hostip>],
                                <hostport>,[<guestip>],<guestport>]

# If the virtual machine is running
VBoxManage --controlvm DevStack natpf<1-N> [<rulename>],tcp|udp,[<hostip>],
                                <hostport>,[<guestip>],<guestport> |
```

For example in order to access the controller machine it will require:

```bash
# HTTP - 80
~ $ VBoxManage controlvm DevStack natpf1 "HTTP, tcp, 127.0.0.1, 80, 10.0.2.15, 80"

# HTTP alternate
~ $ VBoxManage controlvm DevStack natpf1 "HTTP alternate, tcp, 127.0.0.1, 8080, 10.0.2.15, 8080"

# HTTPS - 443
~ $ VBoxManage controlvm DevStack natpf1 "HTTPS, tcp, 127.0.0.1, 443, 10.0.2.15, 443"

```

More information regarding Openstack default ports can be found on [Appendix A. Firewalls and default ports](http://docs.openstack.org/juno/config-reference/content/firewalls-default-ports.html).


##Troubleshooting

###OpenStack role list raises unrecognized arguments: --group

```bash
::./stack.sh:780+openstack role list --group 3c65c1a8d12f40a2a9949d5b2922beae --project 18ab3a46314442b183db43bc13b175b4 --column ID --column Name
usage: openstack role list [-h] [-f {csv,html,json,table,yaml}] [-c COLUMN]
                           [--max-width <integer>]
                           [--quote {all,minimal,none,nonnumeric}]
                           [--project <project>] [--user <user>]
openstack role list: error: unrecognized arguments: --group 3c65c1a8d12f40a2a9949d5b2922beae
```

Code location at `lib/keystone:418`, invoked by `functions-common:773`.

The first reason is that the python-openstackclient version is too old (`openstack --version`), upgrade it:

```bash
~ $ sudo pip install --upgrade python-openstackclient
```

You need to add python-openstackclient to `LIBS_FROM_GIT` in `local.conf`, to make sure DevStack uses the newest version of `python-openstackclient`. Note that, DevStack will use `master` branch of `python-openstackclient` instead of `stable/kilo`.

```ini
# Add python-openstackclient to your LIBS_FROM_GIT
LIBS_FROM_GIT=python-openstackclient
```

The next step, since keystone v2.0 doesn't even have the concept "group", you need to force here to use keystone V3 api.

```diff
diff --git a/functions-common b/functions-common
index c27e623..d6c8f74 100644
--- a/functions-common
+++ b/functions-common
@@ -757,6 +757,7 @@ function get_or_create_role {
 # Gets or adds user role to project
 # Usage: get_or_add_user_project_role <role> <user> <project>
 function get_or_add_user_project_role {
+    local os_url="$KEYSTONE_SERVICE_URI_V3"
     local user_role_id
     # Gets user role id
     user_role_id=$(openstack role list \
@@ -764,6 +765,8 @@ function get_or_add_user_project_role {
         --project $3 \
         --column "ID" \
         --column "Name" \
+        --os-identity-api-version=3 \
+        --os-url=$os_url \
         | grep " $1 " | get_field 1)
     if [[ -z "$user_role_id" ]]; then
         # Adds role to user
@@ -771,6 +774,8 @@ function get_or_add_user_project_role {
             $1 \
             --user $2 \
             --project $3 \
+            --os-identity-api-version=3 \
+            --os-url=$os_url \
             | grep " id " | get_field 2)
     fi
     echo $user_role_id
@@ -779,6 +784,7 @@ function get_or_add_user_project_role {
 # Gets or adds group role to project
 # Usage: get_or_add_group_project_role <role> <group> <project>
 function get_or_add_group_project_role {
+    local os_url="$KEYSTONE_SERVICE_URI_V3"
     local group_role_id
     # Gets group role id
     group_role_id=$(openstack role list \
@@ -786,6 +792,8 @@ function get_or_add_group_project_role {
         --project $3 \
         --column "ID" \
         --column "Name" \
+        --os-identity-api-version=3 \
+        --os-url=$os_url \
         | grep " $1 " | get_field 1)
     if [[ -z "$group_role_id" ]]; then
         # Adds role to group
@@ -793,6 +801,8 @@ function get_or_add_group_project_role {
             $1 \
             --group $2 \
             --project $3 \
+            --os-identity-api-version=3 \
+            --os-url=$os_url \
             | grep " id " | get_field 2)
     fi
     echo $group_role_id
```

```bash
# functions-common.diff contains the above diff
~ $ git apply functions-common.diff
~ $ rm functions-common.diff
```
