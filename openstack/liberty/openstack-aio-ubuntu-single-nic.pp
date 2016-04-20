$install_argus = true

$admin_password = 'Passw0rd'
$demo_password = $admin_password
$admin_token = '4b46b807-ab35-4a67-9f5f-34bbff2dd439'
$metadata_proxy_shared_secret = '39c24deb-0d57-4184-81da-fc8ede37082e'
$region_name = 'RegionOne'

$cinder_lvm_loopback_device_size_mb = 10 * 1024
$cinder_loopback_base_dir = '/var/lib/cinder'
$cinder_loopback_device_file_name = "${cinder_loopback_base_dir}/cinder-volumes.img"
$cinder_lvm_vg = 'cinder-volumes'
$workers = $::processorcount

$interface = 'eth0'
$ext_bridge_interface = 'br-ex'
$dns_nameservers = ['8.8.8.8', '8.8.4.4']
$private_subnet_cidr = '192.168.1.0/24'
$public_subnet_cidr = '10.0.2.0/24'
$public_subnet_gateway = '10.0.2.2'
$public_subnet_allocation_pools = ['start=10.0.2.20,end=10.0.2.50']

# Note: this is executed on the master
$gateway = generate('/bin/sh',
'-c', '/sbin/ip route show | /bin/grep default | /usr/bin/awk \'{print $3}\'')

$ext_bridge_interface_repl = regsubst($ext_bridge_interface, '-', '_')
$ext_bridge_interface_ip = inline_template(
"<%= scope.lookupvar('::ipaddress_${ext_bridge_interface_repl}') -%>")

if $ext_bridge_interface_ip {
  $local_ip = $ext_bridge_interface_ip
  $local_ip_netmask = inline_template(
    "<%= scope.lookupvar('::netmask_${ext_bridge_interface_repl}') -%>")
} 
else {
  $local_ip = inline_template(
    "<%= scope.lookupvar('::ipaddress_${interface}') -%>")
  $local_ip_netmask = inline_template(
    "<%= scope.lookupvar('::netmask_${interface}') -%>")
}

if !$local_ip {
  fail('$local_ip variable must be set')
}
notify { "Local IP: ${local_ip}":}
->
notify { "Netmask: ${local_ip_netmask}":}
->
notify { "Gateway: ${gateway}":}

class { 'apt': }
apt::source { 'ubuntu-cloud':
  location          =>  'http://ubuntu-cloud.archive.canonical.com/ubuntu',
  repos             =>  'main',
  release           =>  'trusty-updates/liberty',
  include_src       =>  false,
  required_packages =>  'ubuntu-cloud-keyring',
}
->
exec { 'apt-update':
    command => '/usr/bin/apt-get update'
}
-> Package <| |>

class { 'mysql::server':
  root_password    => $admin_password,
  override_options => { 'mysqld' => { 'bind_address'           => '0.0.0.0',
                                      'default_storage_engine' => 'InnoDB',
                                      'max_connections'        => 1024,
                                      'open_files_limit'       => -1 } },
  restart          => true,
}

class { 'keystone::db::mysql':
  password      => $admin_password,
  allowed_hosts => '%',
}

class { 'keystone':
  verbose               => true,
  package_ensure        => latest,
  client_package_ensure => latest,
  catalog_type          => 'sql',
  admin_token           => $admin_token,
  database_connection   => "mysql://keystone:${admin_password}@${local_ip}/keystone",
}

# Installs the service user endpoint.
class { 'keystone::endpoint':
  public_url   => "http://${local_ip}:5000",
  internal_url => "http://${local_ip}:5000",
  admin_url    => "http://${local_ip}:35357",
  region       => $region_name,
  version      => "v2.0"
}

keystone_tenant { 'admin':
  ensure  => present,
  enabled => true,
}

keystone_tenant { 'services':
  ensure  => present,
  enabled => true,
}

keystone_tenant { 'demo':
  ensure  => present,
  enabled => true,
}

keystone_user { 'admin':
  ensure   => present,
  enabled  => true,
  password => $admin_password,
  email    => 'admin@openstack',
}

keystone_user { 'demo':
  ensure   => present,
  enabled  => true,
  password => $demo_password,
  email    => 'demo@openstack',
}

keystone_role { 'admin':
  ensure => present,
}

keystone_role { 'demo':
  ensure => present,
}

keystone_user_role { 'admin@admin':
  ensure => present,
  roles  => ['admin'],
}

keystone_user_role { 'admin@services':
  ensure => present,
  roles  => ['admin'],
}

keystone_user_role { 'demo@demo':
  ensure => present,
  roles  => ['demo'],
}

# RabbitMQ

class { '::rabbitmq':
  service_ensure    => 'running',
  port              => '5672',
  delete_guest_user => true,
}

rabbitmq_user { 'openstack':
  admin    => false,
  password => $admin_password,
  tags     => ['openstack'],
}

rabbitmq_vhost { '/':
  ensure => present,
}

rabbitmq_user_permissions { 'openstack@/':
  configure_permission => '.*',
  read_permission      => '.*',
  write_permission     => '.*',
}

# Glance

class { 'glance::api':
  verbose             => true,
  keystone_tenant     => 'services',
  keystone_user       => 'glance',
  keystone_password   => $admin_password,
  database_connection => "mysql://glance:${admin_password}@${local_ip}/glance",
  workers             => $api_workers,
}

class { 'glance::registry':
  verbose             => true,
  keystone_tenant     => 'services',
  keystone_user       => 'glance',
  keystone_password   => $admin_password,
  database_connection => "mysql://glance:${admin_password}@${local_ip}/glance",
}

class { 'glance::backend::file': }

class { 'glance::db::mysql':
  password      => $admin_password,
  allowed_hosts => '%',
}

class { 'glance::keystone::auth':
  password     => $admin_password,
  email        => 'glance@example.com',
  public_url   => "http://${local_ip}:9292",
  admin_url    => "http://${local_ip}:9292",
  internal_url => "http://${local_ip}:9292",
  region       => $region_name,
}

class { 'glance::notify::rabbitmq':
  rabbit_password => $admin_password,
  rabbit_userid   => 'openstack',
  rabbit_hosts    => ["${local_ip}:5672"],
  rabbit_use_ssl  => false,
}

keystone_user_role { 'glance@services':
  ensure => present,
  roles  => ['admin'],
}

exec { 'retrieve_cirros_image':
  command => 'wget -q http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img \
    -O /tmp/cirros-0.3.4-x86_64-disk.img',
  unless  => [ "glance --os-username admin \
    --os-tenant-name admin \
    --os-password ${admin_password} \
    --os-auth-url http://${local_ip}:35357/v2.0 \
    image-show cirros-0.3.4-x86_64" ],
  path    => [ '/usr/bin/', '/bin' ],
  require => [ Class['glance::api'], Class['glance::registry'] ]
}
->
exec { 'add_cirros_image':
  command => "glance --os-username admin \
    --os-tenant-name admin \
    --os-password ${admin_password} \
    --os-auth-url http://${local_ip}:35357/v2.0 image-create \
    --name cirros-0.3.4-x86_64 --file /tmp/cirros-0.3.4-x86_64-disk.img \
    --disk-format qcow2 --container-format bare --is-public True",
  # Avoid dependency warning
  onlyif  => [ 'test -f /tmp/cirros-0.3.4-x86_64-disk.img' ],
  path    => [ '/usr/bin/', '/bin' ],
}
->
file { '/tmp/cirros-0.3.4-x86_64-disk.img':
  ensure => absent,
}

# Nova

keystone_service { 'nova':
  ensure      => present,
  type        => 'compute',
  description => 'Openstack Compute Service',
}

keystone_endpoint { "${region_name}/nova":
  ensure       => present,
  public_url   => "http://${local_ip}:8774/v2/%(tenant_id)s",
  admin_url    => "http://${local_ip}:8774/v2/%(tenant_id)s",
  internal_url => "http://${local_ip}:8774/v2/%(tenant_id)s",
}

keystone_user { 'nova':
  ensure   => present,
  enabled  => True,
  password => $admin_password,
  email    => 'nova@openstack',
}

keystone_user_role { 'nova@services':
  ensure => present,
  roles  => ['admin'],
}

class { 'nova':
  database_connection =>
    "mysql://nova:${admin_password}@${local_ip}/nova?charset=utf8",
  rabbit_userid       => 'openstack',
  rabbit_password     => $admin_password,
  image_service       => 'nova.image.glance.GlanceImageService',
  glance_api_servers  => "${local_ip}:9292",
  verbose             => true,
  rabbit_host         => $local_ip,
}

class { 'nova::db::mysql':
  password      => $admin_password,
  allowed_hosts => '%',
}

class { 'nova::api':
  enabled                              => true,
  auth_uri                             => "http://${local_ip}:5000/v2.0",
  identity_uri                         => "http://${local_ip}:35357",
  admin_user                           => 'nova',
  admin_password                       => $admin_password,
  admin_tenant_name                    => 'services',
  neutron_metadata_proxy_shared_secret => $metadata_proxy_shared_secret,
  osapi_compute_workers                => $api_workers,
  ec2_workers                          => $api_workers,
  metadata_workers                     => $api_workers,
  validate                             => true,
}

class { 'nova::network::neutron':
  neutron_admin_password  => $admin_password,
}

class { 'nova::scheduler':
  enabled => true,
}

class { 'nova::conductor':
  enabled => true,
  workers => $api_workers,
}

class { 'nova::consoleauth':
  enabled => true,
}

class { 'nova::cert':
  enabled => true,
}

class { 'nova::objectstore':
  enabled => true,
}

class { 'nova::compute':
  enabled           => true,
  vnc_enabled       => true,
  vncproxy_host     => $local_ip,
  vncproxy_protocol => 'http',
  vncproxy_port     => '6080',
}

class { 'nova::vncproxy':
  enabled           => true,
  vncproxy_protocol => 'http',
  host              => '0.0.0.0',
  port              => '6080',
}

class { 'nova::compute::libvirt':
  migration_support => true,
  # Narrow down listening if not needed for troubleshooting
  vncserver_listen  => '0.0.0.0',
  libvirt_virt_type => 'kvm',
}

# Neutron

keystone_service { 'neutron':
  ensure      => present,
  type        => 'network',
  description => 'Openstack Networking Service',
}

keystone_endpoint { "${region_name}/neutron":
  ensure       => present,
  public_url   => "http://${local_ip}:9696",
  admin_url    => "http://${local_ip}:9696",
  internal_url => "http://${local_ip}:9696",
}

keystone_user { 'neutron':
  ensure   => present,
  enabled  => true,
  password => $admin_password,
  email    => 'neutron@openstack',
}

keystone_user_role { 'neutron@services':
  ensure => present,
  roles  => ['admin'],
}

class { '::neutron':
  enabled               => true,
  bind_host             => '0.0.0.0',
  rabbit_host           => $local_ip,
  rabbit_user           => 'openstack',
  rabbit_password       => $admin_password,
  verbose               => true,
  debug                 => false,
  core_plugin           => 'ml2',
  service_plugins       => ['router', 'metering'],
  allow_overlapping_ips => true,
}

class { 'neutron::server':
  auth_user           => 'neutron',
  auth_password       => $admin_password,
  auth_tenant         => 'services',
  auth_uri            => "http://${local_ip}:5000/v2.0",
  identity_uri        => "http://${local_ip}:35357",
  database_connection =>
    "mysql://neutron:${admin_password}@${local_ip}/neutron?charset=utf8",
  sync_db             => true,
  api_workers         => $api_workers,
  rpc_workers         => $api_workers,
}

class { 'neutron::db::mysql':
  password      => $admin_password,
  allowed_hosts => '%',
}

class { '::neutron::server::notifications':
  nova_admin_tenant_name => 'services',
  nova_admin_password    => $admin_password,
}

class { '::neutron::agents::ml2::ovs':
  local_ip         => $local_ip,
  enable_tunneling => true,
  tunnel_types     => ['gre', 'vxlan'],
  bridge_mappings  => ['physnet1:br-ex'],
}
->
vs_port { 'eth0':
  ensure => present,
  bridge => 'br-ex',
}
->
network::interface { 'br-ex':
  ipaddress       => $local_ip,
  netmask         => $local_ip_netmask,
  gateway         => $gateway,
  dns_nameservers => join($dns_nameservers, ' '),
}

Vs_port['eth0']
->
network::interface { 'eth0':
  method => 'manual',
  up     => [ 'ifconfig $IFACE 0.0.0.0 up', 'ip link set $IFACE promisc on' ],
  down   => [ 'ip link set $IFACE promisc off', 'ifconfig $IFACE down' ],
}

vs_bridge { 'br-int':
  ensure => present,
}

vs_bridge { 'br-tun':
  ensure => present,
}

class { '::neutron::plugins::ml2':
  type_drivers         => ['flat', 'vlan', 'gre', 'vxlan'],
  tenant_network_types => ['flat', 'vlan', 'gre', 'vxlan'],
  vxlan_group          => '239.1.1.1',
  mechanism_drivers    => ['openvswitch'],
  flat_networks        => ['physnet1'],
  vni_ranges           => ['1001:2000'], #VXLAN
  tunnel_id_ranges     => ['1001:2000'], #GRE
  network_vlan_ranges  => ['physnet1:3001:4000'],
}

class { '::neutron::agents::l3':
  external_network_bridge  => 'br-ex',
  router_delete_namespaces => true,
}

class { '::neutron::agents::metadata':
  enabled       => true,
  shared_secret => $metadata_proxy_shared_secret,
  auth_user     => 'neutron',
  auth_password => $admin_password,
  auth_tenant   => 'services',
  auth_url      => "http://${local_ip}:35357/v2.0",
  auth_region   => $region_name,
  metadata_ip   => $local_ip,
}

class { '::neutron::agents::dhcp':
  enabled                => true,
  dhcp_delete_namespaces => true,
}

class { '::neutron::agents::lbaas':
  enabled => true,
}

class { '::neutron::agents::vpnaas':
  enabled => true,
}

class { '::neutron::agents::metering':
  enabled => true,
}

neutron_network { 'public':
  ensure                    => present,
  router_external           => true,
  tenant_name               => 'admin',
  provider_network_type     => 'flat',
  provider_physical_network => 'physnet1',
  shared                    => true,
}

neutron_subnet { 'public_subnet':
  ensure           => present,
  cidr             => $public_subnet_cidr,
  network_name     => 'public',
  tenant_name      => 'admin',
  enable_dhcp      => false,
  gateway_ip       => $public_subnet_gateway,
  allocation_pools => $public_subnet_allocation_pools,
}

neutron_network { 'private':
  ensure                => present,
  tenant_name           => 'demo',
  provider_network_type => 'vlan',
  shared                => false,
}

neutron_subnet { 'private_subnet':
  ensure          => present,
  cidr            => $private_subnet_cidr,
  network_name    => 'private',
  tenant_name     => 'demo',
  enable_dhcp     => true,
  dns_nameservers => $dns_nameservers,
}

neutron_router { 'demo_router':
  ensure               => present,
  tenant_name          => 'demo',
  gateway_network_name => 'public',
  require              => Neutron_subnet['public_subnet'],
}

neutron_router_interface { 'demo_router:private_subnet':
  ensure => present,
}

# Horizon

package { 'apache2':
  ensure => latest,
}

service { 'apache2':
    ensure  => running,
    enable  => true,
    require => Package['apache2'],
}

class { 'memcached':
  listen_ip => '127.0.0.1',
  tcp_port  => '11211',
  udp_port  => '11211',
}
->
package { 'openstack-dashboard':
  ensure => latest,
}
->
file_line { 'dashboard_openstack_host':
  ensure => present,
  path   => '/etc/openstack-dashboard/local_settings.py',
  line   => "OPENSTACK_HOST = '${local_ip}'",
  match  => '^OPENSTACK_HOST\s=.*',
}
->
file_line { 'dashboard_default_role':
  ensure => present,
  path   => '/etc/openstack-dashboard/local_settings.py',
  line   => 'OPENSTACK_KEYSTONE_DEFAULT_ROLE = \'user\'',
  match  => '^OPENSTACK_KEYSTONE_DEFAULT_ROLE\s=.*',
}

->
package { 'openstack-dashboard-ubuntu-theme':
  ensure   => latest,
}
~> Service['apache2']

# Cinder

keystone_service { 'cinder':
  ensure      => present,
  type        => 'volume',
  description => 'OpenStack Block Storage',
}

keystone_endpoint { "${region_name}/cinder":
  ensure       => present,
  public_url   => "http://${local_ip}:8776/v2/%(tenant_id)s",
  admin_url    => "http://${local_ip}:8776/v2/%(tenant_id)s",
  internal_url => "http://${local_ip}:8776/v2/%(tenant_id)s",
}

keystone_service { 'cinderv2':
  ensure      => present,
  type        => 'volumev2',
  description => 'OpenStack Block Storage',
}

keystone_endpoint { "${region_name}/cinderv2":
  ensure       => present,
  public_url   => "http://${local_ip}:8776/v2/%(tenant_id)s",
  admin_url    => "http://${local_ip}:8776/v2/%(tenant_id)s",
  internal_url => "http://${local_ip}:8776/v2/%(tenant_id)s",
}

keystone_user { 'cinder':
  ensure   => present,
  enabled  => true,
  password => $admin_password,
  email    => 'cinder@openstack',
}

keystone_user_role { 'cinder@services':
  ensure => present,
  roles  => ['admin'],
}

class { 'cinder':
  database_connection => "mysql://cinder:${admin_password}@${local_ip}/cinder",
  rabbit_userid       => 'openstack',
  rabbit_password     => $admin_password,
  rabbit_host         => $local_ip,
  verbose             => true,
}

class { 'cinder::api':
  enabled           => true,
  keystone_user     => 'cinder',
  keystone_password => $admin_password,
  auth_uri          => "http://${local_ip}:5000/v2.0",
  identity_uri      => "http://${local_ip}:35357",
  sync_db           => true,
  service_workers   => $api_workers,
  #validate          => true, # Fails with a V2 API endpoint
}

class { 'cinder::db::mysql':
  password      => $admin_password,
  allowed_hosts => '%',
}

class { 'cinder::scheduler':
  enabled          => true,
  scheduler_driver => 'cinder.scheduler.simple.SimpleScheduler',
}

class { 'cinder::volume':
  enabled => true,
}

file { $cinder_loopback_base_dir:
  ensure => directory,
}
->
exec { 'create_cinder_lvm_loopback_file':
  command => "dd if=/dev/zero of=${cinder_loopback_device_file_name} bs=1M \
count=0 seek=${cinder_lvm_loopback_device_size_mb} && \
losetup /dev/loop0 ${cinder_loopback_device_file_name} && \
pvcreate /dev/loop0 && vgcreate ${cinder_lvm_vg} /dev/loop0",
  path    => ['/usr/bin/', '/bin', '/sbin'],
  unless  => "vgdisplay ${cinder_lvm_vg}",
  creates => $cinder_loopback_device_file_name,
}
->
file_line { 'create_cinder_lvm_loopback_file_rc_local':
  ensure => present,
  path   => '/etc/rc.local',
  # TODO: Initialize the loopback device somewhere else
  line   => "/sbin/losetup -f ${cinder_loopback_device_file_name} &",
}
->
file_line { 'rc_local_remove_exit':
  ensure => absent,
  path   => '/etc/rc.local',
  line   => 'exit 0',
}
->
class { 'cinder::volume::iscsi':
  iscsi_ip_address => $local_ip,
  volume_driver    => 'cinder.volume.drivers.lvm.LVMVolumeDriver',
  volume_group     => $cinder_lvm_vg,
}

# Keystone files to be sourced

file { '/root/keystonerc_admin':
  ensure  => present,
  content =>
"export OS_AUTH_URL=http://${local_ip}:35357/v2.0
export OS_USERNAME=admin
export OS_PASSWORD=${admin_password}
export OS_TENANT_NAME=admin
export OS_VOLUME_API_VERSION=2
",
}

file { '/root/keystonerc_demo':
  ensure  => present,
  content =>
"export OS_AUTH_URL=http://${local_ip}:35357/v2.0
export OS_USERNAME=demo
export OS_PASSWORD=${demo_password}
export OS_TENANT_NAME=demo
export OS_VOLUME_API_VERSION=2
",
}

class { 'tempest':
    debug                  => true,
    use_stderr             => true,
    log_file               => 'tempest.log',
    
    install_from_source    => true,
    git_clone              => true,
    setup_venv             => true,
    tempest_config_file    => '/etc/tempest/tempest.conf',

    # Clone config
    tempest_repo_uri       => 'git://github.com/openstack/tempest.git',
    tempest_repo_revision  => '7',
    tempest_clone_path     => '/var/lib/tempest',
    lock_path              => '/var/lib/tempest',
    tempest_clone_owner    => 'root',

    identity_uri           => "http://${local_ip}:5000/v2.0",
    identity_uri_v3        => "http://${local_ip}:5000/v3",
    
    # non admin user
    username               => 'demo',
    password               => $demo_password,
    tenant_name            => 'demo',
    
    # admin user
    admin_username         => 'admin',
    admin_password         => $admin_password,
    admin_tenant_name      => 'admin',
    admin_role             => 'admin',
    admin_domain_name      => 'Default',
    
    cinder_available       => true,
    glance_available       => true,
    heat_available         => false,
    ceilometer_available   => false,
    aodh_available         => false,
    horizon_available      => true,
    neutron_available      => true,
    nova_available         => true,
    sahara_available       => false,
    swift_available        => false,
    trove_available        => false,
    keystone_v2            => true,
    keystone_v3            => true,
    
    # Glance image config
    configure_images       => true,
    image_name             => 'cirros',
    image_name_alt         => 'cirros_alt',
    flavor_ref             => '3',
    flavor_ref_alt         => '3',
    img_dir                => '/var/lib/tempest',

    # Neutron network config
    configure_networks     => true,
    public_network_name    => 'public',

    # Horizon dashboard config
    dashboard_url          => "http://${local_ip}/horizon/",
}

# Argus
class argus(
  $argus_clone_path    = '/var/lib/argus',
  $argus_repo_uri      = "git://github.com/cloudbase/cloudbase-init-ci.git",
  $argus_repo_revision = undef,
  $argus_clone_owner   = 'root',

) {

  vcsrepo { $argus_clone_path:
    ensure   => latest,
    require  => Package['git'],
    source   => $argus_repo_uri,
    revision => $argus_repo_revision,
    provider => 'git',
    user     => $argus_clone_owner,
  }

  exec { 'install-requirements':
    command => "${tempest::tempest_clone_path}/.venv/bin/pip install -r requirements.txt",
    cwd     => $argus_clone_path,
    require => Exec['install-pip', 'setup-venv'],
  }

  exec { 'install-argus':
    command => "${tempest::tempest_clone_path}/.venv/bin/python setup.py install",
    cwd     => $argus_clone_path,
    require => Exec['install-requirements']
  }
}

if $install_argus {
  class {'argus': }
}
