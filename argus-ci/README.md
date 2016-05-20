Argus-CI Environment
==================

Create an OpenStack environment using DevStack (more information can be found on the following tutorial [Deploy OpenStack Kilo with DevStack][0]).

### Update the local.conf file

After the step [Change local.conf][1] apply the following patch:

```diff
diff --git a/local.conf b/local.conf
index e563fec..c9ea1b0 100644
--- a/local.conf
+++ b/local.conf

@@ -21,10 +21,11 @@ TROVE_BRANCH=$DEVSTACK_BRANCH
 HORIZON_BRANCH=$DEVSTACK_BRANCH
 TROVE_BRANCH=$DEVSTACK_BRANCH
 REQUIREMENTS_BRANCH=$DEVSTACK_BRANCH
+TEMPEST_BRANCH=tags/7

 Q_PLUGIN=ml2
 Q_ML2_PLUGIN_MECHANISM_DRIVERS=openvswitch
-Q_ML2_TENANT_NETWORK_TYPE=vlan
+Q_ML2_TENANT_NETWORK_TYPE=flat,vlan

 PHYSICAL_NETWORK=physnet1
 OVS_PHYSICAL_BRIDGE=br-eth1
@@ -37,9 +38,9 @@ TENANT_VLAN_RANGE=500:2000
 GUEST_INTERFACE_DEFAULT=eth1
 PUBLIC_INTERFACE_DEFAULT=eth2

 FIXED_NETWORK_SIZE=256
 FIXED_RANGE=10.100.0.0/24
@@ -103,26 +104,29 @@ enable_service c-vol
 enable_service c-sch
 enable_service c-bak

+# Heat
+enable_service heat
+enable_service h-api
+enable_service h-api-cfn
+enable_service h-api-cw
+enable_service h-eng
+
+# Tempest
+enable_service tempest
+
 # Services that should not be installed
 disable_service n-net
 disable_service s-proxy
 disable_service s-object
 disable_service s-container
 disable_service s-account
-disable_service heat
-disable_service h-api
-disable_service h-api-cfn
-disable_service h-api-cw
-disable_service h-eng
 disable_service ceilometer-acompute
 disable_service ceilometer-acentral
 disable_service ceilometer-collector
 disable_service ceilometer-api
-enable_service tempest

 [[post-config|$NEUTRON_CONF]]
 [database]
 min_pool_size = 5
 max_pool_size = 50
	 max_overflow = 50
-
```

###Run stack.sh

```bash
~ $ cd ~/devstack
~ $ ./stack.sh
```

**IMPORTANT:** If the scripts doesn't end properly or something else goes wrong, please unstack first using ```./unstack.sh``` script.

### Continue with the following steps
 
- [Edit ~/.shellrc][2]
- [Run stack.sh][3]
- [Prepare DevStack][4]

### Time Synchronisation with NTP
NTP is a TCP/IP protocol for synchronising time over a network. Basically a client requests the current time from a server, and uses it to set its own clock.

In order to install `ntp` run the following command: 

```bash
~ $ sudo apt-get install ntp
```

Start the service:

```
~ $ sudo service ntp force-reload
```

If the time is not properlly set you can run the following command:

```
~ $ sudo ntpd -qgddd
```

### Prepare the nova flavors for the Argus-CI Project

```bash
nova flavor-delete 1
nova flavor-delete 2
nova flavor-delete 3
nova flavor-delete 4
nova flavor-delete 5
nova flavor-delete 42
nova flavor-delete 84
nova flavor-delete 451
```

```bash
nova flavor-create win-small 1 2048 40 1
nova flavor-create win-medium 2 4096 40 2
nova flavor-create win-large 3 6144 40 4
```

### Install Argus-CI

Clone the repository:

```bash
~ $ git clone https://github.com/cloudbase/cloudbase-init-ci/
```

Switch to the develop branch

```bash
~ $ cd cloudbase-init-ci
~ $ git checkout develop
```

Create a new virtual environment for the Argus-CI project

```bash
~ $ virtualenv .venv/argus-ci --python=/usr/bin/python2.7
~ $ source .venv/argus-ci/bin/activate
(argus-ci) ~ $ pip install pip --upgrade
```

Install the Argus-CI project

```bash
~ $ pip install -r requirements.txt
~ $ python setup.py develop
```

Install the tempest (realease 7)

```bash
(argus-ci) ~ $ cd /opt/stack/tempest/
(argus-ci) ~ $ git checkout tags/7
(argus-ci) ~ $ pip install -r requirements.txt
(argus-ci) ~ $ pip install -r test-requirements.txt
(argus-ci) ~ $ python setup.py install
```

### Setup Argus-CI

```bash
~ $ cd
~ $ sudo ln -s /opt/stack/tempest/etc /etc/tempest
~ $ sudo ln -s ~/cloudbase-init-ci/etc /etc/argus
```

Update the argus.conf

```
# Argus configuration used in production for testing cloudbaseinit

[argus]
path_to_private_key = key.pem
dns_nameservers = 8.8.8.8
resources = https://raw.githubusercontent.com/PCManticore/argus-ci/develop/argus/resources
output_directory = instance
build = Beta
arch = x64
pause = False

[openstack]
# Change the image_ref value
image_ref = <none>
flavor_ref = 3
image_username = CiAdmin
image_password = Passw0rd
image_os_type = Windows
require_sysprep = True

[cloudbaseinit]
created_user = Admin
group = Administrators
```

Update the compute and network sections from `tempest.conf`

```ini
[compute]
# ...
flavor_ref_alt = 2
flavor_ref = 2
image_alt_ssh_user = CiAdmin
# Change the image_ref_alt
image_ref_alt = <none>
# Change the image ref
image_ref = <none>
build_timeout = 800
# ...
```

```ini
[network]
# Update the network information
default_network = 10.100.0.0/24
public_router_id = <none>
public_network_id = <none>
```

[comment]: References
[0]: https://github.com/alexandrucoman/scripts/tree/master/openstack/kilo
[1]: https://github.com/alexandrucoman/scripts/tree/master/openstack/kilo#change-local-conf
[2]: https://github.com/alexandrucoman/scripts/tree/master/openstack/kilo#edit-shellrc
[3]: https://github.com/alexandrucoman/scripts/tree/master/openstack/kilo#run-stack-sh
[4]: https://github.com/alexandrucoman/scripts/tree/master/openstack/kilo#prepare-devstack
