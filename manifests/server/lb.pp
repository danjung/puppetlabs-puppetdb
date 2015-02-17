class puppetdb::server::lb() inherits bioiq_common::puppetdb::params {

  $ssl_path     = '/etc/nginx/ssl'
  $ssl_cert     = 'puppet:///modules/bioiq_common/star.bioiq.com.pem'
  $ssl_cert_key = 'puppet:///modules/bioiq_common/bioiq.com.key'


  class { 'nginx':
    worker_processes => $::processorcount,
  }

  # Turn on httpd_can_network_relay for proxypass in selinux 
  exec { "setsebool -P 'httpd_can_network_relay' true":
    unless => "getsebool 'httpd_can_network_relay' | awk '{ print \$3 }' | grep on",
  }

  $puppetdb_vhost_name    = hiera('puppetdb_http_server_names')
  $puppetboard_vhost_name = hiera('puppetboard_http_server_names')

  # Rewrite non-ssl to ssl
  $rewrite = ["^(.*) https://\$http_host\$request_uri redirect"]
  
  # listen on http
  nginx::resource::vhost { $puppetdb_vhost_name :
    ensure             => present,
    listen_port        => hiera('http_port'),
    ipv6_enable        => $ipv6_enable,
    ipv6_listen_port   => hiera('http_port'),
    server_name        => $puppetdb_vhost_name,
    www_root           => "/usr/share/nginx",
    rewrite            => $rewrite,
  }

  class { 'bioiq_common::lb::ssl' :
    ssl_path      => $ssl_path,
    ssl_cert      => $ssl_cert,
    ssl_cert_key  => $ssl_cert_key,
  }

  # listen on https
  nginx::resource::vhost { "puppetdb-${puppetdb_vhost_name}-https" :
    ensure               => present,
    listen_port          => hiera('http_ssl_port'),
    ipv6_enable          => $ipv6_enable,
    ipv6_listen_port     => hiera('http_ssl_port'),
    ssl                  => true,
    ssl_cert             => $bioiq_common::lb::ssl::ssl_cert_path,
    ssl_key              => $bioiq_common::lb::ssl::ssl_cert_key_path,
    server_name          => $puppetdb_vhost_name,
    auth_basic           => "Restricted",
    auth_file            => "bioiq_common/lb/logstash-${environment}-auth.erb",
    proxy                => hiera('puppetdb_proxy_url'),
    proxy_read_timeout   => 10,
    location_template    => $puppetdb_proxy_template,
    blocked_agents       => $http_blocked_agents,
    require              => Class['bioiq_common::lb::ssl'],
  }

  # For puppetdb performance metrics report
  nginx::resource::vhost { "puppetdb-${puppetdb_vhost_name}" :
    ensure               => present,
    listen_port          => hiera('puppetdb_port'),
    ipv6_enable          => $ipv6_enable,
    ipv6_listen_port     => hiera('puppetdb_port'),
    ssl                  => true,
    ssl_port             => hiera('puppetdb_port'),
    ssl_cert             => $bioiq_common::lb::ssl::ssl_cert_path,
    ssl_key              => $bioiq_common::lb::ssl::ssl_cert_key_path,
    server_name          => $puppetdb_vhost_name,
    proxy                => hiera('puppetdb_proxy_url'),
    proxy_read_timeout   => 10,
    location_template    => $puppetdb_proxy_template,
    blocked_agents       => $http_blocked_agents,
    require              => Class['bioiq_common::lb::ssl'],
  }
  
  # http for puppetboard
  nginx::resource::vhost { $puppetboard_vhost_name :
    ensure             => present,
    listen_port        => hiera('http_port'),
    ipv6_enable        => $ipv6_enable,
    ipv6_listen_port   => hiera('http_port'),
    server_name        => $puppetboard_vhost_name,
    www_root           => "/usr/share/nginx",
    rewrite            => $rewrite,
  }

  # For puppetboard reports
  nginx::resource::vhost { "puppetboard-${puppetboard_vhost_name}" :
    ensure               => present,
    listen_port          => hiera('http_ssl_port'),
    ipv6_enable          => $ipv6_enable,
    ipv6_listen_port     => hiera('http_ssl_port'),
    ssl                  => true,
    ssl_port             => hiera('http_ssl_port'),
    ssl_cert             => $bioiq_common::lb::ssl::ssl_cert_path,
    ssl_key              => $bioiq_common::lb::ssl::ssl_cert_key_path,
    server_name          => $puppetboard_vhost_name,
    auth_basic           => "Restricted",
    auth_file            => "bioiq_common/lb/logstash-${environment}-auth.erb",
    proxy                => hiera('puppetboard_proxy_url'),
    proxy_read_timeout    => 10,
    location_template    => $puppetboard_proxy_template,
    blocked_agents       => $http_blocked_agents,
    require              => Class['bioiq_common::lb::ssl'],
  }
}