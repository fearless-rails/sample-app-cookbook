#
# Cookbook Name:: sample-app
# Recipe:: default
#
# Copyright (C) 2014 Zach Campbell
#

# runs apt-get update for us, basically
include_recipe "apt"

# install redis
include_recipe "redisio::install"
include_recipe "redisio::enable"

# installs the postgresql server
include_recipe "postgresql::server"

# create the postgresql database for our application
include_recipe "database::postgresql"

postgresql_database "sample_app_production" do
  connection(
    host:     'localhost',
    port:     5432,
    username: 'postgres',
    password: node['postgresql']['password']['postgres']
  )
  action :create
end

# add our deploy user
user_account "deploy" do
  action :create
  ssh_keys node['sample-app']['deploy_keys']
end

# install rvm and ruby 2.1.2 for the "deploy" user
node.default['rvm']['user_installs'] = [
  { 'user'          => 'deploy',
    'default_ruby'  => '2.1.2',
    'rubies'        => ['2.1.2']
  }
]

package "gawk" # rvm requirement for installing 2.1.2

include_recipe "rvm::user"

# create an rvm wrapper for our specific version of bundler
rvm_wrapper "deploy" do
  ruby_string "2.1.2@global"
  binary      "bundle"
  user        "deploy"
end

# setup the deployment target directories and configuration files
%w(sample-app sample-app/shared sample-app/shared/config sample-app/shared/tmp sample-app/shared/tmp/pids sample-app/shared/tmp/sockets).each do |dir|
  directory "/home/deploy/#{dir}" do
    action :create
    owner "deploy"
    group "deploy"
    recursive true
  end
end

# add  config/database.yml
template "/home/deploy/sample-app/shared/config/database.yml" do
  variables(
    database: node['sample-app']['database']['database'],
    username: node['sample-app']['database']['username'],
    password: node['sample-app']['database']['password'],
    host:     node['sample-app']['database']['host']
  )
  owner 'deploy'
  group 'deploy'
end

# add unicorn configuration
template "/home/deploy/sample-app/shared/unicorn.rb" do
  variables(
    :pid_file_path => '/home/deploy/sample-app/shared/tmp/pids/unicorn.pid',
    :socket_path   => '/home/deploy/sample-app/shared/tmp/sockets/unicorn.sock',
    :working_directory => '/home/deploy/sample-app/current',
    :worker_processes  => 2
  )
  owner 'deploy'
  group 'deploy'
end

include_recipe 'runit'

# tell runit to run our app
runit_service "sample-app" do
  options({
    :working_dir     => '/home/deploy/sample-app/current',
    :bundle_command  => '/home/deploy/.rvm/bin/deploy_bundle',
    :path_to_gemfile => '/home/deploy/sample-app/current/Gemfile',
    :unicorn_pid     => '/home/deploy/sample-app/shared/tmp/pids/unicorn.pid',
    :unicorn_config  => '/home/deploy/sample-app/shared/unicorn.rb',
    :user            => 'deploy'
  })
  owner 'deploy'
  group 'deploy'
end

# configure god.rb and its runit service
template "/home/deploy/sample-app/shared/config/sample-app.god" do
  variables({
    :rails_root   => '/home/deploy/sample-app/current',
    :worker_count => 2,
    :bundle_command => '/home/deploy/.rvm/bin/deploy_bundle'
  })
end

rvm_gem "god" do
  ruby_string "2.1.2@global"
  action :install
  user "deploy"
end

rvm_wrapper "deploy" do
  ruby_string "2.1.2@global"
  binary      "god"
  user        "deploy"
end

runit_service 'sample-app-god' do
  options({
    :user => 'deploy',
    :group => 'deploy',
    :god_config => '/home/deploy/sample-app/shared/config/sample-app.god',
    :unicorn_pid => '/home/deploy/sample-app/shared/tmp/pids/unicorn.pid',
    :god_command => '/home/deploy/.rvm/bin/deploy_god'
  })
end

# install and configure nginx
include_recipe "nginx"

template "/etc/nginx/sites-available/#{node['sample-app']['hostname']}" do
  source "sample-app-nginx.erb"
  variables({
    :app_name => node['sample-app']['app_name'],
    :unicorn_socket => '/home/deploy/sample-app/shared/tmp/sockets/unicorn.sock',
    :server_name    => node['sample-app']['host_name'],
    :app_root       => '/home/deploy/sample-app/current/public'
  })
end

nginx_site node['sample-app']['hostname']
