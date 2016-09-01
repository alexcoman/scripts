Argus-CI Environment
==================

Create an OpenStack environment using RDO, you can follow this tutorial [Deploy Openstack Mitaka with RDO][1]

### Time Synchronisation with NTP
NTP is a TCP/IP protocol for synchronising time over a network. Basically a client requests the current time from a server, and uses it to set its own clock.

In order to install `ntp` run the following command: 

```bash
~ $ sudo yum install ntp
```

Start the service:

```
~ $ sudo service ntpd force-reload
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
``` ### Install Argus-CI

Clone the repository:

```bash
~ $ git clone https://github.com/cloudbase/cloudbase-init-ci/
```

Create a new virtual environment for the Argus-CI project

```bash
~ $ virtualenv .venv/argus-ci --python=/usr/bin/python2.7
~ $ source .venv/argus-ci/bin/activate
(argus-ci) ~ $ pip install pip --upgrade
```

Install the Argus-CI project

```bash
(argus-ci) ~ $ pip install -r requirements.txt
(argus-ci) ~ $ python setup.py develop
```

Install the tempest (release 11.0.0)

```bash
(argus-ci) ~ $ cd ~/
(argus-ci) ~ $ git clone https://github.com/openstack/tempest.git
(argus-ci) ~ $ cd tempest
(argus-ci) ~ $ git checkout 11.0.0 
(argus-ci) ~ $ pip install ~/tempest
(argus-ci) ~ $ pip install -r requirements.txt
(argus-ci) ~ $ pip install -r test-requirements.txt
(argus-ci) ~ $ python setup.py install
```

### Setup Argus-CI

```bash
~ $ cd
~ $ sudo ln -s ~/cloudbase-init-ci/etc /etc/argus
```

Update the argus.conf

```
# Argus configuration used in production for testing cloudbaseinit

[argus]
path_to_private_key = key.pem
dns_nameservers = 8.8.8.8
resources = https://raw.githubusercontent.com/cloudbase/cloudbase-init-ci/master/argus/resources
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


### Configure tempest

Move the `tempest.conf` file in the apropriate director.(The sample is in this repo)
```bash
~ $ sudo mkdir /etc/tempest
~ $ sudo mv scripts/argus-ci/mitaka/tempest.conf /etc/tempest/tempest.conf
```

Update the compute, identity, auth and network sections from `tempest.conf`

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

```init
[identity]
auth_version = v2
admin_domain_scope = True
uri_v3 = http://<LOCAL IP>/identity/v3
uri = http://<LOCAL IP>:5000/v2.0/
```

```ini
[auth]
use_dynamic_credentials = True
#tempest_roles = Member
admin_domain_name = Default
#admin_tenant_id = 5c99ef506ee54a5d84acc62f4d6781f0
admin_tenant_name = admin
admin_password = <CHANGE>
admin_username = admin
```

```ini
[network]
# Update the network information
default_network = 10.100.0.0/24
public_router_id = <none>
public_network_id = <none>
```

```ini
[dashboard]
dashboard_url = http://<LOCAL IP>/horizon/
```
Where `LOCAL_IP` is the static IP of the host.

All of this info cand be found using :
```bash
(keystonerc_admin)~ $ neutron net-list
(keystonerc_admin)~ $ neutron router-list
(keystonerc_admin)~ $ echo $OS_PASSWORD
```

## Neutron config
Add this line in `/etc/neutron/dnsmasq-neutron.conf`
```ini
~ $ echo "dhcp-option-force=42,188.214.141.10" | sudo tee -a /etc/neutron/dnsmasq-neutron.conf
```

## Heat fix
In order for the Heat Scenario Test to pass we need to edit the `/etc/heat/heat.conf` the `trusts_delegated_roles` field. To avoid any `missing required credential` type of errors, the field should be left empty. And also make sure that you have run `source keystonerc_admin` before running the tests with Argus, as it could possibly not find the required group by itself.

##Remove the hardcoded MTU value set by neutron

By default in the `/etc/neutron/dnsmasq-neutron.conf` there will be a option called `dhcp-option-force=26,1400`, which will force the MTU value of 1400 for any future instances, a better approach being to simply delete this line, so that we don't trigger any unwanted behaviour.

**IMPORTANT 1:** In case git clone or any kind of download doesn't work on the instance, you would need to override the MTU value set in the machine, in order for the packets to pass and not have them dropped.
You can simply run this following command if it happens for the packets to drop: `netsh interface ipv4 set subinterface "Ethernet" mtu=1450 store=persistent` 

[1]: /rdo/openstack-mitaka/README.md
