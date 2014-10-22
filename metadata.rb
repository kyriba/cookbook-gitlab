name             'gitlab'
maintainer       'Marin Jankovski'
maintainer_email 'maxlazio@gmail.com'
license          'MIT'
description      'Installs/Configures GitLab'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.7.4'

recipe "gitlab::default", "Installation"

%w{ redisio ruby_build postgresql mysql database postfix yum-epel phantomjs magic_shell apt monit build-essential omnibus-gitlab }.each do |dep|
  depends dep
end

%w{ debian ubuntu centos }.each do |os|
  supports os
end
