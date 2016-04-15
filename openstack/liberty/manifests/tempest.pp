$admin_password       = 'Passw0rd'
$demo_password        = $admin_password
$interface            = 'eth0'
$ext_bridge_interface = 'br-ex'

# Note: this is executed on the master
$gateway = generate('/bin/sh',
'-c', '/sbin/ip route show | /bin/grep default | /usr/bin/awk \'{print $3}\'')

$ext_bridge_interface_repl = regsubst($ext_bridge_interface, '-', '_')
$ext_bridge_interface_ip = inline_template(
"<%= scope.lookupvar('::ipaddress_${ext_bridge_interface_repl}') -%>")

if $ext_bridge_interface_ip {
  $local_ip = $ext_bridge_interface_ip
} else {
  $local_ip = inline_template(
"<%= scope.lookupvar('::ipaddress_${interface}') -%>")
}

if !$local_ip {
  fail('$local_ip variable must be set')
}

notify { "Local IP: ${local_ip}":}

class { 'tempest':
    debug                  => true,
    use_stderr             => true,
    log_file               => 'tempest.log',
    
    install_from_source    => true,
    git_clone              => true,
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
