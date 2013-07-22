#
# Cookbook Name:: ktc-compute
# Recipe:: compute
#
class ::Chef::Recipe
  include ::Openstack
end

# search for control node and set all the necessary node attributes
# so the nova service gets configured correctly
control_node = config_by_role "os-compute-single-controller"
if control_node
  print "control node ip: #{control_node.ipaddress}"
  node.default["memcached"]["listen"] = control_node.ipaddress
  node.default["openstack"]["compute"]["rabbit"]["host"] = control_node.ipaddress
  node.default["openstack"]["db"]["compute"]["host"] = control_node.ipaddress
end

chef_gem "chef-rewind"
require 'chef/rewind'

include_recipe "openstack-compute::compute"
# Add cgroup_device_acl option to /etc/libvirt/qemu.conf
cookbook_file "/etc/libvirt/qemu.conf" do
  source "qemu.conf.erb"
  owner "nova"
  group "nova"
  mode "0600"
  notifies :restart, resources(:service => "libvirt-bin"), :immediately
end

# Rewind nova-compute.conf template to use the "lb" config source
if node["quantum"]["plugin"] == "lb"
  rewind :template => "/etc/nova/nova-compute.conf" do
    source "folsom/nova-compute.conf.erb"
    cookbook_name "ktc-compute"
  end
end

# apply fixes for nova-compute
include_recipe "ktc-utils"
%w{ 2012.2.1+stable-20121212-a99a802e-0ubuntu1.4~cloud0 2012.2.3-0ubuntu2~cloud0 }.each do |version|
  if ::Chef::Recipe::Patch.check_package_version("nova-compute",version,node)
    template "/usr/share/pyshared/nova/network/quantumv2/api.py" do
      source "ktc-patches/api.py.#{version}"
      owner "root"
      group "root"
      mode "0644"
      notifies :restart, resources(:service => "nova-compute"), :immediately
    end
  end
  if ::Chef::Recipe::Patch.check_package_version("nova-compute",version,node)
    template "/usr/share/pyshared/nova/compute/manager.py" do
      source "ktc-patches/manager.py.#{version}"
      owner "root"
      group "root"
      mode "0644"
      notifies :restart, resources(:service => "nova-compute"), :immediately
    end
  end
end
