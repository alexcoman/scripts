# Deploy OpenStack Mitaka using Packstack

## Step by step tutorial for deploying OpenStack using Packstack from RDO.


##Create the Virtual Machine
- Processors:
    - Number of processors: 2
    - Number of cores per processor 2
- Memory: 6GB RAM (Recommended)
- HDD - SATA - Minimum 100 GB (Recommended *Preallocated*)
- Network:
    - Network Adapter :  **NAT**
- Operating system - **CentOS 7**

Note: The Hypervisor used for this example is **VMWare Workstation 11**

**IMPORTANT:** Do not forget to enable ```Virtualize Intel VT-x/EPT or AMD-V/RVI``` in Processors settings.

**SIDE-NOTE:** The NATs subnet IP in this scenario is 10.0.2.0 with its default gateway set on 10.0.2.2, please change the values used in the tutorial accordingly to your NAT values.
##Setting up the system

###Prepare the network
```bash
~ $ sudo systemctl disable firewalld
~ $ sudo systemctl stop firewalld
~ $ sudo systemctl disable NetworkManager
~ $ sudo systemctl stop NetworkManager
~ $ sudo systemctl enable network
~ $ sudo systemctl start network
~ $ sudo yum remove NetworkManager
```

```bash
# Enable the extras
~ $ sudo yum install -y centos-release-openstack-mitaka

# Update the current packages:
~ $ sudo yum update -y

# Update the system
~ $ sudo yum upgrade

# Install the required tools
~ $ sudo yum install -y git vim openssh-server python-devel openstack-packstack deltarpm yum-utils yum-cron net-tools qemu-kvm qemu-kvm-tools wget

# Clean-up old kernels

~ $ sudo package-cleanup --oldkernels --count 2
```


**IMPORTANT:** For non-English environment make sure your ```/etc/environment``` is populated as it follows:

```bash
~ $ sudo vim /etc/environment
```

```vim
LANG=en_US.utf-8
LC_ALL=en_US.utf-8
```

## Configure the hosts and network

```bash
# Modify the hosts so that it resembles the snippet below
~ $ sudo vim /etc/hosts
```

```vim
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.0.2.22 localhost work-argus-ci-test # The hostname IP should be set accordingly

```


```bash
# Modify the network config, the name might differ

~ $ sudo vim /etc/sysconfig/network-scripts/ifcfg-en-device-name
```

```vim
TYPE=Ethernet
BOOTPROTO=static # Set it to static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME="device-name"
UUID="the-uid"
DEVICE="device-name"
ONBOOT=yes
PEERDNS=yes
PEERROUTES=yes
IPV6_PEERDNS=yes
IPV6_PEERROUTES=yes

IPADDR=10.0.2.22 # Set the IP Address that should be used by the mahcine
NETMASK=255.255.255.0
GATEWAY=10.0.2.2
DNS1=10.0.2.2
DNS2=8.8.8.8

```
## Configure the network_init
```bash
# Restart the network

~ $ sudo service network restart

# Get the network setup script

~ $ wget https://raw.githubusercontent.com/stefan-caraiman/packstack-tutorial/master/network_init.sh
~ $ chmod +x network_init.sh

# Also don't forget to modify the values from the script

# Next we need to have the network_init run at startup
# Add "bash /home/work/network_init.sh" to the end of the following file

~ $ sudo vim /etc/rc.local
~ $ sudo chmod +x /etc/rc.local

# Now reboot the system

~ $ sudo reboot
```

###Installing Openstack with Packstack

```bash
# Install Openstack using our customized answer file.
# Also do not forget to modify the HOST IP fields found in the file.

~ $ wget https://raw.githubusercontent.com/stefan-caraiman/packstack-tutorial/master/packstack-answers.txt

~ $ sudo packstack --answer-file=packstack.txt

# After the install you can find the ```keystonerc_admin``` in your home folder

~ $ sudo su
~ $ source ~/keystonerc_admin

# Copy in the working user home directory

~ $ sudo cp /root/keystonerc_admin ~/
~ $ sudo chown $USER ~/keystonerc_admin

# The password can be found in ```keystonerc_admin``` or by simply echo-ing it

~ $ echo $OS_PASSWORD

# Add the port for the br-ex

~ $ sudo ovs-vsctl add-port br-ex "the-eno-name"
```
You can find `the-eno-name` with `ip a` of `ifconfig`.

## Configure the network with neutron

```bash
# Clear the router gateway

(keystonerc_admin) ~ $ neutron router-gateway-clear router1

# Delete the default public network

(keystonerc_admin) ~ $ neutron net-delete public

# Create a new public network

(keystonerc_admin) ~ $ neutron net-create --shared --router:external public

# Configure the newly created public network

(keystonerc_admin) ~ $ neutron subnet-create public 10.0.2.0/24 --name public_subnet --enable-dhcp=False --allocation-pool start=10.0.2.140,end=10.0.2.160 --gateway 10.0.2.2

# Create a new router and set the gateway for it

(keystonerc_admin) ~ $ neutron router-create router
(keystonerc_admin) ~ $ neutron router-gateway-set $router_id $public_network_id

# Add the private subnet to the routers interfaces

(keystonerc_admin) ~ $ neutron router-interface-add router private_subnet

# Update the private_subnet DNS nameserver
# Run ```neutron subnet-list``` to see the subnets IDs.

(keystonerc_admin) ~ $ neutron subnet-update --dns-nameserver 8.8.8.8 "private_subnet_id"
```


# Update nova.conf
**IMPORTANT 1:** It might happen that nova.conf virt_type value is set on qemu instead of kvm(Windows instaces won't be able to boot up if that's the case). In that case please do the following:
In `/etc/nova/nova.conf` you need to have this configurations set in order to boot windows instances.
```ini
...
virt_type=kvm # by default it might be qemu
...
cpu_model=host-passthrough # by default if might be none 
..
```

```bash
# You can then either reboot the machine or restart the services 

~ $ sudo openstack-service restart
```

## Other details
**IMPORTANT 2:** In case you wish to re-run packstack with a updated answerfile you can simply run the following:

####NOTE: by default ```$youranswerfile``` is called packstack-answer-$date-$time.txt

```bash
~ $ sudo packstack --answer-file=$youranswerfile
```


**IMPORTANT 3:** In the case of Windows 10 and Windows Server 2016 there are some CPU features that have to be enabled.In nova.conf search for the `cpu_mode` field and set it to host-passthrough. Restart the service.

**IMPORTANT 4:** If you encounter issues with generating the tempest config, you can also generate it as it follows:

```bash
#Create your tempest directory and change into it
~ $ mkdir ~/tempest && cd ~/tempest

#Initialize the directory by running
~ $ /usr/share/openstack-tempest-10.0.0/tools/configure-tempest-directory

#Configure tempest
~ $ tools/config_tempest.py --deployer-input ~/tempest-deployer-input.conf \
--create identity.uri $OS_AUTH_URL identity.admin_password $OS_PASSWORD
```

**IMPORTANT 5:** To avoid some errors with running tests, read permissions should be added to the "/etc/neutron" folder.



#### Pip erros
If you upgrated pip `>8.1.0` and installed python packages with `yum` pip might not work(`pip freeze` in particular ).
Force pip to `8.1.0` with this command `sudo pip install pip==8.1.0` this seems a problem for CentOS 7.2
because pip got more strict with package naming.
More info here :
 - https://github.com/pypa/pip/issues/3764
 - https://github.com/pypa/pip/issues/3681

#### ServerFault when runing tempest
 There is a dependency issue with nova when tempest will try to generete a new key pair will get `500` response code
 from the server resulting in a `ServerFault: Got server fault`. To check if this is the error see with `pip freeze` if you have
 `paramiko=2.0.0+` and in `/var/log/nova/nova-api.log` you get something similar with this.

 ```
 api.py", line 4068, in _generate_key_pair
2016-04-29 14:56:58.381 2175 ERROR nova.api.openstack.extensions return crypto.generate_key_pair()
2016-04-29 14:56:58.381 2175 ERROR nova.api.openstack.extensions File "/openstack/venvs/nova-master/lib/python2.7/site-packages/nova/crypto.py", line 152, in generate_key_pair
2016-04-29 14:56:58.381 2175 ERROR nova.api.openstack.extensions key = generate_key(bits)
2016-04-29 14:56:58.381 2175 ERROR nova.api.openstack.extensions File "/openstack/venvs/nova-master/lib/python2.7/site-packages/nova/crypto.py", line 144, in generate_key
2016-04-29 14:56:58.381 2175 ERROR nova.api.openstack.extensions key = paramiko.RSAKey(vals=(rsa.e, rsa.n))
2016-04-29 14:56:58.381 2175 ERROR nova.api.openstack.extensions TypeError: __init__() got an unexpected keyword argument 'vals'
 ```

I think you installed tempest requirements globaly, and that sucks for you, you may need to redeploy.

 More info you can find here :
 - https://bugs.launchpad.net/openstack-ansible/+bug/1576755
 - https://bugs.launchpad.net/python-novaclient/+bug/1365251
 - https://bugs.launchpad.net/nova/+bug/1585515


##For more details please consult the links below:

- https://www.rdoproject.org/install/quickstart/
- https://www.rdoproject.org/networking/neutron-with-existing-external-network/
- https://www.rdoproject.org/networking/floating-ip-range/
- https://www.rdoproject.org/install/adding-a-compute-node/

