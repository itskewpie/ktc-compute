# Cookbook Name:: ktc-compute
# Recipe:: compute-api
#

include_recipe "services"
include_recipe "ktc-utils"

iface = KTC::Network.if_lookup "management"
ip = KTC::Network.address "management"

Services::Connection.new run_context: run_context
compute_metadata_api = Services::Member.new node.default.fqdn,
  service: "compute-metadata-api",
  port: 8775,
  proto: "tcp",
  ip: ip

compute_metadata_api.save
KTC::Network.add_service_nat "compute-metadata-api", 8775

compute_api = Services::Member.new node.default.fqdn,
  service: "compute-api",
  port: 8774,
  proto: "tcp",
  ip: ip

compute_api.save
KTC::Network.add_service_nat "compute-api", 8774

compute_ec2_api = Services::Member.new node.default.fqdn,
  service: "compute-ec2-api",
  port: 8773,
  proto: "tcp",
  ip: ip

compute_ec2_api.save
KTC::Network.add_service_nat "compute-ec2-api", 8773

compute_ec2_admin = Services::Member.new node.default.fqdn,
  service: "compute-ec2-admin",
  port: 8773,
  proto: "tcp",
  ip: ip

compute_ec2_admin.save
KTC::Network.add_service_nat "compute-ec2-admin", 8773

compute_xvpvnc = Services::Member.new node.default.fqdn,
  service: "compute-xvpvnc",
  port: 6081,
  proto: "tcp",
  ip: ip

compute_xvpvnc.save
KTC::Network.add_service_nat "compute-xvpvnc", 6081

compute_novnc = Services::Member.new node.default.fqdn,
  service: "compute-novnc",
  port: 6080,
  proto: "tcp",
  ip: ip

compute_novnc.save
KTC::Network.add_service_nat "compute-novnc", 6080

KTC::Attributes.set

node.default["openstack"]["compute"]["libvirt"]["bind_interface"] = iface
node.default["openstack"]["compute"]["xvpvnc_proxy"]["bind_interface"] = iface
node.default["openstack"]["compute"]["novnc_proxy"]["bind_interface"] = iface

include_recipe "openstack-common"
include_recipe "openstack-common::logging"
include_recipe "openstack-object-storage::memcached"
include_recipe "ktc-compute::nova-common"

service_list = %w{
  scheduler
  conductor
  api-ec2
  api-os-compute
  api-metadata
  cert
  consoleauth
  novncproxy
}

service_list.each do |service|
  cookbook_file "/etc/init/nova-#{service}.conf" do
    source "etc/init/nova-#{service}.conf"
    action :create
  end
end

include_recipe "ark"
ark "novnc" do
  path "/usr/share"
  url node["openstack"]["compute"]["platform"]["novnc"]["url"]
  action :put
end

include_recipe "openstack-compute::nova-setup"
include_recipe "openstack-compute::scheduler"
include_recipe "openstack-compute::conductor"
include_recipe "openstack-compute::api-ec2"
include_recipe "openstack-compute::api-os-compute"
include_recipe "openstack-compute::api-metadata"
include_recipe "openstack-compute::nova-cert"
include_recipe "openstack-compute::vncproxy"

chef_gem "chef-rewind"
require 'chef/rewind'

service_list.each do |service|
  rewind :service => "nova-#{service}" do
    provider Chef::Provider::Service::Upstart
  end
end

include_recipe "openstack-compute::identity_registration"
