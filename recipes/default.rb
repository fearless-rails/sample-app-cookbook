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
