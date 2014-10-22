# -*- mode: ruby -*-
# vi: set ft=ruby :

# Throw an error if required Vagrant plugins are not installed
plugins = { 'vagrant-berkshelf' => '2.0.1', 'vagrant-omnibus' => nil, 'vagrant-bindfs' => nil }

plugins.each do |plugin, version|
  unless Vagrant.has_plugin? plugin
    error = "The '#{plugin}' plugin is not installed! Try running:\nvagrant plugin install #{plugin}"
    error += " --plugin-version #{version}" if version
    raise error
  end
end


# You can ask for more memory and cores when creating your Vagrant machine:
# GITLAB_VAGRANT_MEMORY=2048 GITLAB_VAGRANT_CORES=4 vagrant up
MEMORY = ENV['GITLAB_VAGRANT_MEMORY'] || '1536'
CORES = ENV['GITLAB_VAGRANT_CORES'] || '2'

# Determine if we need to forward ports
FORWARD = ENV['GITLAB_VAGRANT_FORWARD'] || '1'

Vagrant.configure("2") do |config|
  config.vm.hostname = "gitlab-dev"

  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  config.vm.provider "vmware_fusion" do |vmware, override|
    override.vm.box = "precise64_fusion"
    override.vm.box_url = "http://files.vagrantup.com/precise64_vmware_fusion.box"
  end

  # Assign this VM to a host-only network IP, allowing you to access it
  # via the IP. Host-only networks can talk to the host machine as well as
  # any other machines on the same network, but cannot be accessed (through this
  # network interface) by any external networks.
  config.vm.network :private_network, ip: "192.168.3.4"

  if FORWARD.to_i > 0
    config.vm.network :forwarded_port, guest: 3000, host: 3000
    config.vm.network :forwarded_port, guest: 80, host: 8888
  end

  # Remove the default Vagrant directory sync
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Sync the 'vagrant' directory on the host to /gitlab on guest
  # Use NFS on Linux/OS X and SMB on Windows
  config.nfs.map_uid = Process.uid
  config.nfs.map_gid = Process.gid

  if Vagrant::Util::Platform.windows?
    config.vm.synced_folder "vagrant", "/gitlab", create: true
  else
    config.vm.synced_folder "vagrant", "/vagrant-nfs", :create => true, :nfs => true
    config.bindfs.bind_folder "/vagrant-nfs", "/gitlab", :owner => "vagrant", :group => "vagrant", :'create-as-user' => true, :perms => "u=rwx:g=rwx:o=rD", :'create-with-perms' => "u=rwx:g=rwx:o=rD", :'chown-ignore' => true, :'chgrp-ignore' => true, :'chmod-ignore' => true
  end

  config.vm.provider :virtualbox do |v|
    # Use VBoxManage to customize the VM. For example to change memory:
    v.customize ["modifyvm", :id, "--memory", MEMORY.to_i]
    v.customize ["modifyvm", :id, "--cpus", CORES.to_i]

    if CORES.to_i > 1
      v.customize ["modifyvm", :id, "--ioapic", "on"]
    end
  end

  config.vm.provider :vmware_fusion do |v, override|
    override.vm.box_url = "http://files.vagrantup.com/precise64_vmware.box"
    v.vmx["memsize"] = MEMORY
    v.vmx["numvcpus"] = CORES
  end

  config.vm.provider :parallels do |v, override|
    v.customize ["set", :id, "--memsize", MEMORY, "--cpus", CORES]
  end

  # Install Chef with Vagrant Omnibus
  # version is :latest or "11.4.4"
  # Note:
  # Using version "11.4.4" because that is the latest version
  # AWS OpsWorks supports
  config.omnibus.chef_version = "11.4.4"

  # Enabling the Berkshelf plugin. To enable this globally, add this configuration
  # option to your ~/.vagrant.d/Vagrantfile file
  config.berkshelf.enabled = true

  config.vm.provision :chef_solo do |chef|
    chef.json = {
      "gitlab" => {
        "env" => "development",
        "user" => "vagrant",
        "group" => "vagrant",
        "home" => "/home/vagrant",
        "path" => "/gitlab/gitlab",
        "satellites_path" => "/gitlab/gitlab-satellites",
        "repos_path" => "/gitlab/repositories",
        "shell_path" => "/gitlab/gitlab-shell"
      },
      "phantomjs" => {
        "version" => "1.8.1"
      }
    }
    chef.run_list = [
      "apt",
      "postfix",
      "gitlab::default",
      "gitlab::vagrant"
    ]
    # Enable verbose console output
    chef.arguments = '-l debug'
  end
end
