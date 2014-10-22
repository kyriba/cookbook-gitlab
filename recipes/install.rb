#
# Cookbook Name:: gitlab
# Recipe:: install
#

gitlab = node['gitlab']

### Copy the example GitLab config
template File.join(gitlab['path'], 'config', 'gitlab.yml') do
  source "gitlab.yml.erb"
  user gitlab['user']
  group gitlab['group']
  variables({
    :host => gitlab['host'],
    :port => gitlab['port'],
    :user => gitlab['user'],
    :email_from => gitlab['email_from'],
    :issue_closing_pattern => gitlab['issue_closing_pattern'],
    :max_size => gitlab['max_size'],
    :git_timeout => gitlab['git_timeout'],
    :satellites_path => gitlab['satellites_path'],
    :satellites_timeout => gitlab['satellites_timeout'],
    :repos_path => gitlab['repos_path'],
    :shell_path => gitlab['shell_path'],
    :signup_enabled => gitlab['signup_enabled'],
    :signin_enabled => gitlab['signin_enabled'],
    :projects_limit => gitlab['projects_limit'],
    :user_can_create_group => gitlab['user_can_create_group'],
    :user_can_change_username => gitlab['user_can_change_username'],
    :default_theme => gitlab['default_theme'],
    :repository_downloads_path => gitlab['repository_downloads_path'],
    :oauth_enabled => gitlab['oauth_enabled'],
    :oauth_block_auto_created_users => gitlab['oauth_block_auto_created_users'],
    :oauth_allow_single_sign_on => gitlab['oauth_allow_single_sign_on'],
    :oauth_providers => gitlab['oauth_providers'],
    :google_analytics_id => gitlab['extra']['google_analytics_id'],
    :sign_in_text => gitlab['extra']['sign_in_text'],
    :default_projects_features => gitlab['default_projects_features'],
    :webhook_timeout => gitlab['webhook_timeout'],
    :gravatar => gitlab['gravatar'],
    :gravatar_plain_url => gitlab['gravatar_plain_url'],
    :gravatar_ssl_url => gitlab['gravatar_ssl_url'],
    :ldap_config => gitlab['ldap'],
    :ldap_servers => gitlab['ldap_servers'],
    :ssh_port => gitlab['ssh_port'],
    :backup => gitlab['backup'],
  })
  notifies :run, "bash[git config]", :immediately
  notifies :reload, "service[gitlab]"
end

### Make sure GitLab can write to the log/ and tmp/ directories
### Create directories for sockets/pids
### Create public/uploads directory otherwise backup will fail
%w{log tmp tmp/pids tmp/sockets public/uploads}.each do |folder|
  path = File.join(gitlab['path'], folder)

  directory path do
    owner gitlab['user']
    group gitlab['group']
    mode 0755
    not_if { File.exist?(path) }
  end
end

### Create directory for satellites
directory gitlab['satellites_path'] do
  owner gitlab['user']
  group gitlab['group']
  mode 0750
  not_if { File.exist?(gitlab['satellites_path']) }
end

### Unicorn config
template File.join(gitlab['path'], 'config', 'unicorn.rb') do
  source "unicorn.rb.erb"
  user gitlab['user']
  group gitlab['group']
  variables({
    :app_root => gitlab['path'],
    :unicorn_workers_number => gitlab['unicorn_workers_number'],
    :unicorn_timeout => gitlab['unicorn_timeout']
  })
  notifies :reload, "service[gitlab]"
end

### Enable Rack attack
# Creating the file this way for the following reasons
# 1. Chef 11.4.0 must be used to keep support for AWS OpsWorks
# 2. Using file resource is not an option because it is ran at compilation time
# and at that point the file doesn't exist
# 3. Using cookbook_file resource is not an option because we do not want to include the file
# in the cookbook for maintenance reasons. Same for template resource.
# 4. Using remote_file resource is not an option because Chef 11.4.0 connects to remote URI
# see https://github.com/opscode/chef/blob/11.4.4/lib/chef/resource/remote_file.rb#L63
# 5 Using bash and execute resource is not an option because they would run at every chef run
# and supplying a restriction in the form of "not_if" would prevent an update of a file
# if there is any
# Ruby block is compiled at compilation time but only executed during execution time
# allowing us to create a resource.

ruby_block "Copy from example rack attack config" do
  block do
    resource = Chef::Resource::File.new("rack_attack.rb", run_context)
    resource.path File.join(gitlab['path'], 'config', 'initializers', 'rack_attack.rb')
    resource.content IO.read(File.join(gitlab['path'], 'config', 'initializers', 'rack_attack.rb.example'))
    resource.owner gitlab['user']
    resource.group gitlab['group']
    resource.mode 0644
    resource.run_action :create
    if resource.updated?
      self.notifies :reload, resources(:service => "gitlab")
    end
  end
end

### Configure Git global settings for git user, useful when editing via web
bash "git config" do
  code <<-EOS
    git config --global user.name "GitLab"
    git config --global user.email "gitlab@#{gitlab['host']}"
    git config --global core.autocrlf input
  EOS
  user gitlab['user']
  group gitlab['group']
  environment('HOME' => gitlab['home'])
  action :nothing
end

## Configure GitLab DB settings
template File.join(gitlab['path'], "config", "database.yml") do
  source "database.yml.#{gitlab['database_adapter']}.erb"
  user gitlab['user']
  group gitlab['group']
  variables({
    :user => gitlab['database_user'],
    :password => gitlab['database_password'],
    :host => node[gitlab['database_adapter']]['server_host'],
    :socket => gitlab['database_adapter'] == "mysql" ? node['mysql']['server']['socket'] : nil
  })
  notifies :reload, "service[gitlab]"
end

file File.join(gitlab['path'], "config", "resque.yml") do
  content "#{gitlab['env']}: unix:#{gitlab['redis_unixsocket']}"
  user gitlab['user']
  group gitlab['group']
end

### Load db schema
execute "rake db:schema:load" do
  command <<-EOS
    PATH="/usr/local/bin:$PATH"
    bundle exec rake db:schema:load
  EOS
  cwd gitlab['path']
  user gitlab['user']
  group gitlab['group']
  environment ({'RAILS_ENV' => gitlab['env']})
  action :nothing
  subscribes :run, "mysql_database[gitlabhq_database]"
  subscribes :run, "postgresql_database[gitlabhq_database]"
end

### db:migrate
execute "rake db:migrate" do
  command <<-EOS
    PATH="/usr/local/bin:$PATH"
    bundle exec rake db:migrate
  EOS
  cwd gitlab['path']
  user gitlab['user']
  group gitlab['group']
  environment ({'RAILS_ENV' => gitlab['env']})
  action :nothing
  subscribes :run, "git[clone gitlabhq source]"
  subscribes :run, "execute[rake db:schema:load]"
end

### db:seed_fu
execute "rake db:seed_fu" do
  command <<-EOS
    PATH="/usr/local/bin:$PATH"
    bundle exec rake db:seed_fu
  EOS
  cwd gitlab['path']
  user gitlab['user']
  group gitlab['group']
  environment ({'RAILS_ENV' => gitlab['env'], 'GITLAB_ROOT_PASSWORD' => gitlab['admin_root_password'] })
  action :nothing
  subscribes :run, "execute[rake db:schema:load]"
end

## Setup Init Script
# Creating the file this way for the following reasons
# 1. Chef 11.4.0 must be used to keep support for AWS OpsWorks
# 2. Using file resource is not an option because it is ran at compilation time
# and at that point the file doesn't exist
# 3. Using cookbook_file resource is not an option because we do not want to include the file
# in the cookbook for maintenance reasons. Same for template resource.
# 4. Using remote_file resource is not an option because Chef 11.4.0 connects to remote URI
# see https://github.com/opscode/chef/blob/11.4.4/lib/chef/resource/remote_file.rb#L63
# 5 Using bash and execute resource is not an option because they would run at every chef run
# and supplying a restriction in the form of "not_if" would prevent an update of a file
# if there is any
# Ruby block is compiled at compilation time but only executed during execution time
# allowing us to create a resource.

ruby_block "Copy from example gitlab init config" do
  block do
    resource = Chef::Resource::File.new("gitlab_init", run_context)
    resource.path "/etc/init.d/gitlab"
    resource.content IO.read(File.join(gitlab['path'], "lib", "support", "init.d", "gitlab"))
    resource.mode 0755
    resource.run_action :create
  end
end

template "/etc/default/gitlab" do
  source "gitlab.default.erb"
  mode 0755
  variables(
    :app_user => node['gitlab']['user'],
    :app_root => node['gitlab']['path']
  )
end

case gitlab['env']
when 'production'
  ## Setup logrotate
  # Creating the file this way for the following reasons
  # 1. Chef 11.4.0 must be used to keep support for AWS OpsWorks
  # 2. Using file resource is not an option because it is ran at compilation time
  # and at that point the file doesn't exist
  # 3. Using cookbook_file resource is not an option because we do not want to include the file
  # in the cookbook for maintenance reasons. Same for template resource.
  # 4. Using remote_file resource is not an option because Chef 11.4.0 connects to remote URI
  # see https://github.com/opscode/chef/blob/11.4.4/lib/chef/resource/remote_file.rb#L63
  # 5 Using bash and execute resource is not an option because they would run at every chef run
  # and supplying a restriction in the form of "not_if" would prevent an update of a file
  # if there is any
  # Ruby block is compiled at compilation time but only executed during execution time
  # allowing us to create a resource.

  ruby_block "Copy from example logrotate config" do
    block do
      resource = Chef::Resource::File.new("logrotate", run_context)
      resource.path "/etc/logrotate.d/gitlab"
      resource.content IO.read(File.join(gitlab['path'], "lib", "support", "logrotate", "gitlab"))
      resource.mode 0644
      resource.run_action :create
    end
  end

  # SMTP email settings
  if gitlab['smtp']['enabled']
    smtp = gitlab['smtp']
    template File.join(gitlab['path'], 'config', 'initializers', 'smtp_settings.rb') do
      source "smtp_settings.rb.erb"
      user gitlab['user']
      group gitlab['group']
      variables({
        :address => smtp['address'],
        :port => smtp['port'],
        :username => smtp['username'],
        :password => smtp['password'],
        :domain => smtp['domain'],
        :authentication => smtp['authentication'],
        :enable_starttls_auto => smtp['enable_starttls_auto']
      })
      notifies :reload, "service[gitlab]"
    end
  end

  template "aws.yml" do
    owner gitlab['user']
    group gitlab['group']
    path "#{gitlab['path']}/config/aws.yml"
    mode 0755
    variables({
      :aws_access_key_id => gitlab['aws']['aws_access_key_id'],
      :aws_secret_access_key => gitlab['aws']['aws_secret_access_key'],
      :bucket => gitlab['aws']['bucket'],
      :region => gitlab['aws']['region'],
      :host => gitlab['aws']['host'],
      :endpoint => gitlab['aws']['endpoint']
    })
    notifies :reload, "service[gitlab]"

    only_if { gitlab['aws']['enabled'] }
  end

  execute "rake assets:clean" do
    command <<-EOS
      PATH="/usr/local/bin:$PATH"
      bundle exec rake assets:clean RAILS_ENV=#{gitlab['env']}
    EOS
    cwd gitlab['path']
    user gitlab['user']
    group gitlab['group']
    action :nothing
    subscribes :run, "execute[rake db:migrate]", :immediately
  end

  execute "rake assets:precompile" do
    command <<-EOS
      PATH="/usr/local/bin:$PATH"
      bundle exec rake assets:precompile RAILS_ENV=#{gitlab['env']}
    EOS
    cwd gitlab['path']
    user gitlab['user']
    group gitlab['group']
    action :nothing
    subscribes :run, "execute[rake db:migrate]", :immediately
  end

  execute "rake cache:clear" do
    command <<-EOS
      PATH="/usr/local/bin:$PATH"
      bundle exec rake cache:clear RAILS_ENV=#{gitlab['env']}
    EOS
    cwd gitlab['path']
    user gitlab['user']
    group gitlab['group']
    action :nothing
    subscribes :run, "execute[rake db:migrate]", :immediately
  end
else
  ## For execute javascript test
  include_recipe "phantomjs"
end
