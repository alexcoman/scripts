Argus-CI Environment
==================

Create an OpenStack environment using ROD .

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

Install the tempest (realease 11)

```bash
(argus-ci) ~ $ cd ~/
(argus-ci) ~ $ git clone clone https://github.com/openstack/tempest.git
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


Move the `tempest.conf` file in the apropriate director.
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
