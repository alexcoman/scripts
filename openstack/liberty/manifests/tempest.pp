$admin_password = 'Passw0rd'
$demo_password = $admin_password
$admin_token = '4b46b807-ab35-4a67-9f5f-34bbff2dd439'
$metadata_proxy_shared_secret = '39c24deb-0d57-4184-81da-fc8ede37082e'

class tempest(
  $install_from_source       = true,
  $git_clone                 = true,
  $tempest_config_file       = '/etc/tempest.conf',

  # Clone config
  #
  $tempest_repo_uri          = 'git://github.com/openstack/tempest.git',
  $tempest_repo_revision     = '7',
  $tempest_clone_path        = '/var/lib/tempest',
  $tempest_clone_owner       = 'root',

  $setup_venv                = false,

  # Glance image config
  #
  $configure_images          = true,
  $image_name                = 'CHANGE_ME',
  $image_name_alt            = 'CHANGE_ME',

  # Neutron network config
  #
  $configure_networks        = true,
  $public_network_name       = 'public',

  # Horizon dashboard config
  $login_url                 = undef,
  $dashboard_url             = 'http://${local_ip}/horizon',

  # tempest.conf parameters
  #
  $identity_uri              = "http://${local_ip}:35357",
  $identity_uri_v3           = undef,
  $cli_dir                   = undef,
  $lock_path                 = '/var/lib/tempest',
  $debug                     = true,
  $verbose                   = true,
  $use_stderr                = true,
  $use_syslog                = false,
  $log_file                  = 'tempest.log',
  # non admin user
  $username                  = 'demo',
  $password                  = $demo_password,
  $tenant_name               = 'demo',
  # another non-admin user
  $alt_username              = undef,
  $alt_password              = undef,
  $alt_tenant_name           = undef,
  # admin user
  $admin_username            = 'admin',
  $admin_password            = $admin_password,
  $admin_tenant_name         = 'admin',
  $admin_role                = 'admin',
  $admin_domain_name         = undef,
  # image information
  $image_ref                 = undef,
  $image_ref_alt             = undef,
  $image_ssh_user            = undef,
  $image_alt_ssh_user        = undef,
  $flavor_ref                = 3,
  $flavor_ref_alt            = 3,
  # whitebox
  $whitebox_db_uri           = undef,
  # testing features that are supported
  $resize_available          = undef,
  $change_password_available = undef,
  $allow_tenant_isolation    = undef,
  # neutron config
  $public_network_id         = undef,
  # Upstream has a bad default - set it to empty string.
  $public_router_id          = '',
  # Service configuration
  $cinder_available          = true,
  $glance_available          = true,
  $heat_available            = false,
  $ceilometer_available      = false,
  $aodh_available            = false,
  $horizon_available         = true,
  $neutron_available         = true,
  $nova_available            = true,
  $sahara_available          = false,
  $swift_available           = false,
  $trove_available           = false,
  $keystone_v2               = true,
  $keystone_v3               = true,
  $auth_version              = 'v2',
  # scenario options
  $img_dir                   = '/var/lib/tempest',
  $img_file                  = 'cirros-0.3.4-x86_64-disk.img',
) {

  include '::tempest::params'

  if $install_from_source {
    ensure_packages([
      'git',
      'python-setuptools',
    ])

    ensure_packages($tempest::params::dev_packages)

    exec { 'install-pip':
      command => '/usr/bin/easy_install pip',
      unless  => '/usr/bin/which pip',
      require => Package['python-setuptools'],
    }

    exec { 'install-tox':
      command => "${tempest::params::pip_bin_path}/pip install -U tox",
      unless  => '/usr/bin/which tox',
      require => Exec['install-pip'],
    }

    if $git_clone {
      vcsrepo { $tempest_clone_path:
        ensure   => 'present',
        source   => $tempest_repo_uri,
        revision => $tempest_repo_revision,
        provider => 'git',
        require  => Package['git'],
        user     => $tempest_clone_owner,
      }
      Vcsrepo<||> -> Tempest_config<||>
    }

    if $setup_venv {
      # virtualenv will be installed along with tox
      exec { 'setup-venv':
        command => "/usr/bin/python ${tempest_clone_path}/tools/install_venv.py",
        cwd     => $tempest_clone_path,
        unless  => "/usr/bin/test -d ${tempest_clone_path}/.venv",
        require => [
          Exec['install-tox'],
          Package[$tempest::params::dev_packages],
        ],
      }
      if $git_clone {
        Vcsrepo<||> -> Exec['setup-venv']
      }
    }

    $tempest_conf = "${tempest_clone_path}/etc/tempest.conf"

    Tempest_config {
      path    => $tempest_conf,
    }
  } else {
    Tempest_config {
      path => $tempest_config_file,
    }
  }

  tempest_config {
    'compute/change_password_available': value => $change_password_available;
    'compute/flavor_ref':                value => $flavor_ref;
    'compute/flavor_ref_alt':            value => $flavor_ref_alt;
    'compute/image_alt_ssh_user':        value => $image_alt_ssh_user;
    'compute/image_ref':                 value => $image_ref;
    'compute/image_ref_alt':             value => $image_ref_alt;
    'compute/image_ssh_user':            value => $image_ssh_user;
    'compute/resize_available':          value => $resize_available;
    'compute/allow_tenant_isolation':    value => $allow_tenant_isolation;
    'identity/admin_password':           value => $admin_password, secret => true;
    'identity/admin_tenant_name':        value => $admin_tenant_name;
    'identity/admin_username':           value => $admin_username;
    'identity/admin_role':               value => $admin_role;
    'identity/admin_domain_name':        value => $admin_domain_name;
    'identity/alt_password':             value => $alt_password, secret => true;
    'identity/alt_tenant_name':          value => $alt_tenant_name;
    'identity/alt_username':             value => $alt_username;
    'identity/password':                 value => $password, secret => true;
    'identity/tenant_name':              value => $tenant_name;
    'identity/uri':                      value => $identity_uri;
    'identity/uri_v3':                   value => $identity_uri_v3;
    'identity/username':                 value => $username;
    'identity/auth_version':             value => $auth_version;
    'identity-feature-enabled/api_v2':   value => $keystone_v2;
    'identity-feature-enabled/api_v3':   value => $keystone_v3;
    'network/public_network_id':         value => $public_network_id;
    'network/public_router_id':          value => $public_router_id;
    'dashboard/login_url':               value => $login_url;
    'dashboard/dashboard_url':           value => $dashboard_url;
    'service_available/cinder':          value => $cinder_available;
    'service_available/glance':          value => $glance_available;
    'service_available/heat':            value => $heat_available;
    'service_available/ceilometer':      value => $ceilometer_available;
    'service_available/aodh':            value => $aodh_available;
    'service_available/horizon':         value => $horizon_available;
    'service_available/neutron':         value => $neutron_available;
    'service_available/nova':            value => $nova_available;
    'service_available/sahara':          value => $sahara_available;
    'service_available/swift':           value => $swift_available;
    'service_available/trove':           value => $trove_available;
    'whitebox/db_uri':                   value => $whitebox_db_uri;
    'cli/cli_dir':                       value => $cli_dir;
    'oslo_concurrency/lock_path':        value => $lock_path;
    'DEFAULT/debug':                     value => $debug;
    'DEFAULT/verbose':                   value => $verbose;
    'DEFAULT/use_stderr':                value => $use_stderr;
    'DEFAULT/use_syslog':                value => $use_syslog;
    'DEFAULT/log_file':                  value => $log_file;
    'scenario/img_dir':                  value => $img_dir;
    'scenario/img_file':                 value => $img_file;
  }

  if $configure_images {
    if ! $image_ref and $image_name {
      # If the image id was not provided, look it up via the image name
      # and set the value in the conf file.
      tempest_glance_id_setter { 'image_ref':
        ensure            => present,
        tempest_conf_path => $tempest_conf,
        image_name        => $image_name,
      }
      Glance_image<||> -> Tempest_glance_id_setter['image_ref']
      Tempest_config<||> -> Tempest_glance_id_setter['image_ref']
      Keystone_user_role<||> -> Tempest_glance_id_setter['image_ref']
    } elsif ($image_name and $image_ref) or (! $image_name and ! $image_ref) {
      fail('A value for either image_name or image_ref must be provided.')
    }
    if ! $image_ref_alt and $image_name_alt {
      tempest_glance_id_setter { 'image_ref_alt':
        ensure            => present,
        tempest_conf_path => $tempest_conf,
        image_name        => $image_name_alt,
      }
      Glance_image<||> -> Tempest_glance_id_setter['image_ref_alt']
      Tempest_config<||> -> Tempest_glance_id_setter['image_ref_alt']
      Keystone_user_role<||> -> Tempest_glance_id_setter['image_ref_alt']
    } elsif ($image_name_alt and $image_ref_alt) or (! $image_name_alt and ! $image_ref_alt) {
        fail('A value for either image_name_alt or image_ref_alt must \
be provided.')
    }
  }

  if $neutron_available and $configure_networks {
    if ! $public_network_id and $public_network_name {
      tempest_neutron_net_id_setter { 'public_network_id':
        ensure            => present,
        tempest_conf_path => $tempest_conf,
        network_name      => $public_network_name,
      }
      Neutron_network<||> -> Tempest_neutron_net_id_setter['public_network_id']
      Tempest_config<||> -> Tempest_neutron_net_id_setter['public_network_id']
      Keystone_user_role<||> -> Tempest_neutron_net_id_setter['public_network_id']
    } elsif ($public_network_name and $public_network_id) or (! $public_network_name and ! $public_network_id) {
      fail('A value for either public_network_id or public_network_name \
  must be provided.')
    }
  }
}
