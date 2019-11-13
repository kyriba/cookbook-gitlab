#
# Cookbook Name:: gitlab
# Recipe:: gems
#

gitlab = node['gitlab']

# To prevent random failures during bundle install, get the latest ca-bundle and update rubygems

directory "/opt/local/etc/certs/" do
  owner gitlab['user']
  group gitlab['group']
  recursive true
  mode 0755
end

remote_file "Fetch the latest ca-bundle" do
  source "http://curl.haxx.se/ca/cacert.pem"
  path "/opt/local/etc/certs/cacert.pem"
  owner gitlab['user']
  group gitlab['group']
  mode 0755
  action :create
  notifies :run, 'execute[Update rubygems]', :immediately
end

execute 'Update rubygems' do
  command 'gem update --system'
  action :nothing
end

## Install Gems without ri and rdoc
template File.join(gitlab['home'], ".gemrc") do
  source "gemrc.erb"
  user gitlab['user']
  group gitlab['group']
  action :create
end

### without
bundle_without = []
case gitlab['database_adapter']
when 'mysql'
  bundle_without << 'postgres'
when 'postgresql'
  bundle_without << 'mysql'

end
bundle_without << 'aws' unless gitlab['aws']['enabled']

case gitlab['env']
when 'production'
  bundle_without << 'development'
  bundle_without << 'test'
else
  bundle_without << 'production'
end

bundle_cfg = ::File.join(gitlab['path'], '.bundle/config')

execute 'bundle mirror config' do
  command "bundle config --local mirror.https://rubygems.org #{gitlab['bundle_mirror']}"
  cwd gitlab['path']
  user gitlab['user']
  not_if { ::File.exist?(bundle_cfg) && ::File.open(bundle_cfg).each_line.any? { |line| line =~ /#{gitlab['bundle_mirror']}/ } }
end unless gitlab['bundle_mirror'].empty?

execute "bundle install" do
  command <<-EOS
    PATH="#{gitlab['postgresql']['configuration_dir']}:/usr/local/bin:$PATH"
    #{gitlab['bundle_install']} --without #{bundle_without.join(" ")}
  EOS
  cwd gitlab['path']
  user gitlab['user']
  group gitlab['group']
  not_if { ::File.directory?(::File.join(gitlab['path'], '.bundle', 'ruby')) }
end
