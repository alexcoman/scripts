bcbio-nextgen-vm - Azure experimental
-------------------------------------

##Workflow

At every ```vagrant up``` the ```bcbio-setup.sh``` script will be runned.

- load_config
	- the constants from ```bcbio-azure/provision/default.conf``` will be exposed
	- if the config file is malformed the execution the script will end with return code 5 
- pip_cache
	- create the pip cache directory if not exists
- install_bcbio
	- if the project is already installed on the virtual machine it will be removed
	- the branch specified in the config file will be cloned
	- all the bcbio requirements will be installed
	- the bcbio-nextgen-vm will be installed
- install_ansible
	- remove the old version of the ansible if it is already installed
	- remove the old version of the azure-ansible if it is already installed
	- install the latest version of the azure-ansible
- install_elasticluster
	- remove the old version of the elasticluster if it is already installed
	- remove the old version of the azure-elasticluster if it is already installed
	- install the latest version of azure-elasticluster
- management_cert
	- if the management certificate exists in the shared directory, it will be copied in the virtual machine
	- generate a new management certificate and copy it to the shared directory
- ssh_keys
	- generate a new SSH key if it does not exist
- ssh_permissions
	- change the permissions for the files from ~/.ssh directory
- elasticluster_config
	- if the azure.config already exists in  the shared directory copy it to the virtual machine
	- otherwise, generate a new config file and copy it to the shared directory
 
 ##How to create the environment

```
$ git clone https://github.com/alexandrucoman/vagrant-environment.git
$ cd vagrant-environment/bcbio-azure
$ vagrant up
$ vagrant ssh 
```
