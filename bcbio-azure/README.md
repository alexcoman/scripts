bcbio-nextgen-vm - Azure experimental
-------------------------------------

##Environment for bcbio-nextgen-vm

###Start or create the environment
```
$ git clone https://github.com/alexandrucoman/vagrant-environment.git
$ cd vagrant-environment/bcbio-azure
$ vagrant box update
$ vagrant up
```

```
==> bcbio-azure: Reinstall python-setuptools
==> bcbio-azure: bcbio-nextgen-vm==0.1.0a0
==> bcbio-azure: Removing the old version of bcbio-nextgen-vm.
==> bcbio-azure: Cloning the bcbio-nextgen-vm project.
==> bcbio-azure: Replace the elasticluster version from requirements.txt
==> bcbio-azure: Installing bcbio-nextgen-vm requirements.
==> bcbio-azure: Installing pybedtools in order to avoid MemoryError.
==> bcbio-azure: Installing the bcbio-nextgen-vm project.
==> bcbio-azure: Remove the current version of elasticluster.
==> bcbio-azure: Install azure-elasticluster.
==> bcbio-azure: Enforce ansible version 1.7.2
==> bcbio-azure: Remove the current version of ansible.
==> bcbio-azure: Copy managementCert.cer from /vagrant/provision/.shared.
==> bcbio-azure: Copy managementCert.pem from /vagrant/provision/.shared.
==> bcbio-azure: Change permisions for ~/.ssh directory.
==> bcbio-azure: Change permisions for managementCert
==> bcbio-azure: Change permisions for ~/.ansible
==> bcbio-azure: The /home/vagrant/.bcbio/elasticluster/azure.config already exists.
==> bcbio-azure: Vagrant is using the last version of elasticluster config.
```

###Stop or destroy the environment
```
$ vagrant halt
```

```
$ vagrant destroy
```

##Elasticluster with azure

###Create a cluster
```
$ vagrant ssh
$ elasticluster --storage /home/vagrant/.bcbio/elasticluster/storage \
                --config /home/vagrant/.bcbio/elasticluster/azure.config \
                --verbose start bcbio
```

```
Starting cluster `bcbio` with 2 compute nodes.
Starting cluster `bcbio` with 1 frontend nodes.
(this may take a while...)
INFO:gc3.elasticluster:Starting node compute001.
INFO:gc3.elasticluster:Starting node compute002.
INFO:gc3.elasticluster:Starting node frontend001.
[...]
```

###Re-run the setup

```
$ elasticluster --storage /home/vagrant/.bcbio/elasticluster/storage
                --config /home/vagrant/.bcbio/elasticluster/azure.config
                --verbose setup bcbio
```

```
Configuring cluster `bcbio`...

PLAY [Collecting facts] *******************************************************

GATHERING FACTS ***************************************************************
ok: [compute002]
ok: [frontend001]
ok: [compute001]
[...]
```

###Destroy the cluster
```
$ elasticluster --storage /home/vagrant/.bcbio/elasticluster/storage \
                --config /home/vagrant/.bcbio/elasticluster/azure.config \
                --verbose stop bcbio
```

```
Do you want really want to stop cluster bcbio? [yN] Y
Destroying cluster `bcbio`
INFO:gc3.elasticluster:shutting down instance `bcbio_vm0000_bcbio-compute001`
INFO:gc3.elasticluster:shutting down instance `bcbio_vm0001_bcbio-compute002`
INFO:gc3.elasticluster:shutting down instance `bcbio_vm0002_bcbio-frontend001`
```
