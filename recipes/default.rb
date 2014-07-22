#
# Cookbook Name:: sample-app
# Recipe:: default
#
# Copyright (C) 2014 Zach Campbell
#

# runs apt-get update for us, basically
include_recipe "apt"

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
    :pid_file_path => '/home/deploy/sample-app/shared/pids/unicorn.pid',
    :socket_path   => '/home/deploy/sample-app/shared/sockets/unicorn.sock',
    :working_directory => '/home/deploy/sample-app/current',
    :worker_processes  => 2
  )
  owner 'deploy'
  group 'deploy'
end
