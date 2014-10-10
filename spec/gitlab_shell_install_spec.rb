require 'spec_helper'

describe "gitlab::gitlab_shell_install" do
  let(:chef_run) { ChefSpec::Runner.new.converge("gitlab::gitlab_shell_install") }


  describe "under ubuntu" do
    ["14.04", "12.04", "10.04"].each do |version|
      let(:chef_run) do
        runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
        runner.node.set['gitlab']['env'] = "production"
        runner.converge("gitlab::gitlab_shell_install")
      end

      it 'creates a gitlab shell config' do
        expect(chef_run).to create_template('/home/git/gitlab-shell/config.yml').with(
          source: 'gitlab_shell.yml.erb',
          variables: {
            user: "git",
            home: "/home/git",
            url: "http://localhost:80/",
            repos_path: "/home/git/repositories",
            redis_path: "/usr/local/bin/redis-cli",
            redis_host: "127.0.0.1",
            redis_port: "6379",
            redis_database: nil,
            redis_port: "0",
            redis_unixsocket: "/var/run/redis/sockets/redis.sock",
            namespace: "resque:gitlab",
            self_signed_cert: false
          }
        )
      end

      it 'creates repository directory in the gitlab user home directory' do
        expect(chef_run).to create_directory("/home/git/repositories").with(
          user: 'git',
          group: 'git',
          mode: 02770
        )
      end

      it 'creates .ssh directory in the gitlab user home directory' do
        expect(chef_run).to create_directory("/home/git/.ssh").with(
          user: 'git',
          group: 'git',
          mode: 0700
        )
      end

      it 'creates authorized hosts file in .ssh directory' do
        expect(chef_run).to create_file_if_missing("/home/git/.ssh/authorized_keys").with(
          user: 'git',
          group: 'git',
          mode: 0600
        )
      end

      it 'does not run a execute to install gitlab shell on its own' do
        expect(chef_run).to_not run_execute('gitlab-shell install')
      end

      describe "when customizing gitlab user home" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['home'] = "/data/git"
          runner.node.set['gitlab']['redis_database'] = 2
          runner.node.set['gitlab']['redis_unixsocket'] = "/var/run/redis/sockets/redis.sock"
          runner.converge("gitlab::gitlab_shell_install")
        end

        it 'creates a gitlab shell config' do
          expect(chef_run).to create_template('/data/git/gitlab-shell/config.yml').with(
            source: 'gitlab_shell.yml.erb',
            variables: {
              user: "git",
              home: "/data/git",
              url: "http://localhost:80/",
              repos_path: "/data/git/repositories",
              redis_path: "/usr/local/bin/redis-cli",
              redis_host: "127.0.0.1",
              redis_port: "0",
              redis_database: 2,
              redis_unixsocket: "/var/run/redis/sockets/redis.sock",
              namespace: "resque:gitlab",
              self_signed_cert: false
            }
          )
        end

        it 'creates repository directory in the gitlab user home directory' do
          expect(chef_run).to create_directory("/data/git/repositories")
        end

        it 'creates .ssh directory in the gitlab user home directory' do
          expect(chef_run).to create_directory("/data/git/.ssh")
        end

        it 'creates authorized hosts file in .ssh directory' do
          expect(chef_run).to create_file_if_missing("/data/git/.ssh/authorized_keys")
        end
      end
    end
  end

  describe "under centos" do
    ["5.8", "6.4"].each do |version|
      let(:chef_run) do
        runner = ChefSpec::Runner.new(platform: "centos", version: version)
        runner.node.set['gitlab']['env'] = "production"
        runner.node.set['gitlab']['redis_database'] = 3
        runner.node.set['gitlab']['redis_unixsocket'] = "/var/run/redis/sockets/redis.sock"
        runner.converge("gitlab::gitlab_shell_install")
      end

      it 'creates a gitlab shell config' do
        expect(chef_run).to create_template('/home/git/gitlab-shell/config.yml').with(
          source: 'gitlab_shell.yml.erb',
          variables: {
            user: "git",
            home: "/home/git",
            url: "http://localhost:80/",
            repos_path: "/home/git/repositories",
            redis_path: "/usr/local/bin/redis-cli",
            redis_host: "127.0.0.1",
            redis_port: "0",
            redis_database: 3,
            redis_unixsocket: "/var/run/redis/sockets/redis.sock",
            namespace: "resque:gitlab",
            self_signed_cert: false
          }
        )
      end

      it 'creates repository directory in the gitlab user home directory' do
        expect(chef_run).to create_directory("/home/git/repositories").with(
          user: 'git',
          group: 'git',
          mode: 02770
        )
      end

      it 'creates .ssh directory in the gitlab user home directory' do
        expect(chef_run).to create_directory("/home/git/.ssh").with(
          user: 'git',
          group: 'git',
          mode: 0700
        )
      end

      it 'creates authorized hosts file in .ssh directory' do
        expect(chef_run).to create_file_if_missing("/home/git/.ssh/authorized_keys").with(
          user: 'git',
          group: 'git',
          mode: 0600
        )
      end

      it 'does not run a execute to install gitlab shell on its own' do
        expect(chef_run).to_not run_execute('gitlab-shell install')
      end

      describe "when customizing gitlab user home" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['home'] = "/data/git"
          runner.converge("gitlab::gitlab_shell_install")
        end

        it 'creates a gitlab shell config' do
          expect(chef_run).to create_template('/data/git/gitlab-shell/config.yml').with(
            source: 'gitlab_shell.yml.erb',
            variables: {
              user: "git",
              home: "/data/git",
              url: "http://localhost:80/",
              repos_path: "/data/git/repositories",
              redis_path: "/usr/local/bin/redis-cli",
              redis_host: "127.0.0.1",
              redis_port: "6379",
              redis_database: nil,
              redis_port: "0",
              redis_unixsocket: "/var/run/redis/sockets/redis.sock",
              namespace: "resque:gitlab",
              self_signed_cert: false
            }
          )
        end

        it 'creates repository directory in the gitlab user home directory' do
          expect(chef_run).to create_directory("/data/git/repositories")
        end

        it 'creates .ssh directory in the gitlab user home directory' do
          expect(chef_run).to create_directory("/data/git/.ssh")
        end

        it 'creates authorized hosts file in .ssh directory' do
          expect(chef_run).to create_file_if_missing("/data/git/.ssh/authorized_keys")
        end
      end
    end
  end
end
