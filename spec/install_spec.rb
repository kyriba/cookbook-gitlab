require 'spec_helper'

describe "gitlab::install" do
  let(:chef_run) { ChefSpec::Runner.new.converge("gitlab::start","gitlab::install") }


  describe "under ubuntu" do
    ["14.04", "14.04", "12.04", "10.04"].each do |version|
      let(:chef_run) do
        runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
        runner.node.set['gitlab']['env'] = "production"
        runner.converge("gitlab::start","gitlab::install")
      end

      it 'creates a gitlab config' do
        expect(chef_run).to create_template('/home/git/gitlab/config/gitlab.yml').with(
          source: 'gitlab.yml.erb',
          variables: {
            host: 'localhost',
            port: '80',
            user: 'git',
            email_from: 'gitlab@localhost',
            issue_closing_pattern: "([Cc]lose[sd]|[Ff]ixe[sd]) #(\d+)",
            max_size: '20971520',
            git_timeout: 10,
            satellites_path: '/home/git/gitlab-satellites',
            satellites_timeout: 30,
            repos_path: '/home/git/repositories',
            shell_path: '/home/git/gitlab-shell',
            signup_enabled: false,
            signin_enabled: true,
            projects_limit: 10,
            user_can_create_group: true,
            user_can_change_username: true,
            default_theme: 2,
            repository_downloads_path: 'tmp/repositories',
            oauth_enabled: false,
            oauth_block_auto_created_users: true,
            oauth_allow_single_sign_on: false,
            oauth_providers: [],
            google_analytics_id: "",
            sign_in_text: "",
            ssh_port: "22",
            default_projects_features: {
              "issues"=>true,
              "merge_requests"=>true,
              "wiki"=>true,
              "snippets"=>false,
              "visibility_level"=>"private"
              },
            webhook_timeout: 10,
            gravatar: true,
            gravatar_plain_url: "http://www.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon",
            gravatar_ssl_url: "https://secure.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon",
            ldap_config: {
              "enabled"=>false,
              "host"=>"_your_ldap_server",
              "base"=>"_the_base_where_you_search_for_users",
              "port"=>636,
              "uid"=>"sAMAccountName",
              "method"=>"ssl",
              "bind_dn"=>"_the_full_dn_of_the_user_you_will_bind_with",
              "password"=>"_the_password_of_the_bind_user",
              "allow_username_or_email_login"=>true,
              "user_filter"=>"",
              "group_base"=>"",
              "admin_group"=>"",
              "sync_ssh_keys"=>false,
              "sync_time"=>3600
            },
            ldap_servers: {},
            backup: {
              "enable"=>true,
              "cron"=>{
                "action"=>:create,
                "minute"=>0,
                "hour"=>2,
                "mailto"=>"gitlab@localhost",
                "path"=>"/usr/local/bin:/usr/bin:/bin"
              },
              "backup_keep_time"=>0,
              "backup_path"=>"tmp/backups"
            }
          }
        )
      end

      describe "creating gitlab.yml" do
        let(:template) { chef_run.template('/home/git/gitlab/config/gitlab.yml') }

        it 'triggers updating of git config' do
          expect(template).to notify('bash[git config]').to(:run).immediately
        end

        it 'updates git config' do
          resource = chef_run.find_resource(:bash, 'git config')
          expect(resource.code).to eq("    git config --global user.name \"GitLab\"\n    git config --global user.email \"gitlab@localhost\"\n    git config --global core.autocrlf input\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.environment).to eq('HOME' =>"/home/git")
        end
      end

      it 'creates required directories in the rails root' do
        %w{log tmp tmp/pids tmp/sockets public/uploads}.each do |path|
          expect(chef_run).to create_directory("/home/git/gitlab/#{path}").with(
            user: 'git',
            group: 'git',
            mode: 0755
          )
        end
      end

      it 'creates satellites directory' do
       expect(chef_run).to create_directory("/home/git/gitlab-satellites").with(
          user: 'git',
          group: 'git'
        )
      end

      it 'creates a unicorn config' do
        expect(chef_run).to create_template('/home/git/gitlab/config/unicorn.rb').with(
          source: 'unicorn.rb.erb',
          variables: {
            app_root: "/home/git/gitlab",
            unicorn_workers_number: 2,
            unicorn_timeout: 30
          }
        )
      end

      it 'copies rack_attack.rb example file' do
        expect(chef_run).to run_ruby_block('Copy from example rack attack config')
      end

      describe "creating rack_attack.rb" do

        it 'triggers uncommenting the line in application.rb' do
          expect(chef_run).to run_ruby_block('Copy from example rack attack config')
        end
      end

      describe "when using mysql" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['database_adapter'] = "mysql"
          runner.node.set['gitlab']['database_password'] = "datapass"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a database config' do
          expect(chef_run).to create_template('/home/git/gitlab/config/database.yml').with(
            source: 'database.yml.mysql.erb',
            user: 'git',
            group: 'git',
            variables: {
              user: 'git',
              password: 'datapass',
              host: "localhost",
              socket: "/var/run/mysqld/mysqld.sock"
            }
          )
        end
      end

      describe "when using mysql with custom server socket" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['database_adapter'] = "mysql"
          runner.node.set['gitlab']['database_password'] = "datapass"
          runner.node.set['mysql']['server']['socket'] = "/tmp/mysql.sock"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a database config' do
          expect(chef_run).to create_template('/home/git/gitlab/config/database.yml').with(
            source: 'database.yml.mysql.erb',
            user: 'git',
            group: 'git',
            variables: {
              user: 'git',
              password: 'datapass',
              host: "localhost",
              socket: "/tmp/mysql.sock"
            }
          )
        end
      end

      describe "when using postgresql" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['database_adapter'] = "postgresql"
          runner.node.set['gitlab']['database_password'] = "datapass"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a database config' do
          expect(chef_run).to create_template('/home/git/gitlab/config/database.yml').with(
            source: 'database.yml.postgresql.erb',
            user: 'git',
            group: 'git',
            variables: {
              user: 'git',
              password: 'datapass',
              host: "localhost",
              socket: nil
            }
          )
        end
      end

      describe "running database setup, migrations and seed when production" do
        it 'runs an execute to rake db:schema:load' do
          expect(chef_run).not_to run_execute('rake db:schema:load')
        end

        it 'runs db setup' do
          resource = chef_run.find_resource(:execute, 'rake db:schema:load')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:schema:load\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV" => "production")
        end

        it 'runs an execute to rake db:migrate' do
          expect(chef_run).not_to run_execute('rake db:migrate')
        end

        it 'runs db migrate' do
          resource = chef_run.find_resource(:execute, 'rake db:migrate')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:migrate\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV" => "production")
        end

        it 'runs an execute to rake db:seed' do
          expect(chef_run).not_to run_execute('rake db:seed_fu')
        end

        it 'runs db seed' do
          resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"production", "GITLAB_ROOT_PASSWORD"=>nil)
        end
      end

      describe "when supplying root password" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['admin_root_password'] = "NEWPASSWORD"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'runs db seed' do
          resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"production", "GITLAB_ROOT_PASSWORD"=>"NEWPASSWORD")
        end
      end

      describe "running database setup, migrations and seed when development" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "development"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'runs an execute to rake db:schema:load' do
          expect(chef_run).not_to run_execute('rake db:schema:load')
        end

        it 'runs db setup for all environments' do
          resources = chef_run.find_resources(:execute).select {|n| n.name == "rake db:schema:load"}
          dev_resource = resources.first

          expect(dev_resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:schema:load\n")
          expect(dev_resource.user).to eq("git")
          expect(dev_resource.group).to eq("git")
          expect(dev_resource.cwd).to eq("/home/git/gitlab")
          expect(dev_resource.environment).to eq("RAILS_ENV"=>"development")
        end

        it 'runs an execute to rake db:migrate' do
          expect(chef_run).not_to run_execute('rake db:migrate')
        end

        it 'runs db migrate for all environments' do
          resources = chef_run.find_resources(:execute).select {|n| n.name == "rake db:migrate"}
          dev_resource = resources.first

          expect(dev_resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:migrate\n")
          expect(dev_resource.user).to eq("git")
          expect(dev_resource.group).to eq("git")
          expect(dev_resource.cwd).to eq("/home/git/gitlab")
          expect(dev_resource.environment).to eq("RAILS_ENV"=>"development")
        end

        it 'runs an execute to rake db:seed' do
          expect(chef_run).not_to run_execute('rake db:seed_fu')
        end

        it 'runs db seed' do
          resources = chef_run.find_resources(:execute).select {|n| n.name == "rake db:seed_fu"}
          dev_resource = resources.first

          expect(dev_resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(dev_resource.user).to eq("git")
          expect(dev_resource.group).to eq("git")
          expect(dev_resource.cwd).to eq("/home/git/gitlab")
          expect(dev_resource.environment).to eq("RAILS_ENV"=>"development", "GITLAB_ROOT_PASSWORD"=>nil)
        end
      end

      describe "when supplying root password in development" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "development"
          runner.node.set['gitlab']['admin_root_password'] = "NEWPASSWORD"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'runs db seed' do
          resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"development", "GITLAB_ROOT_PASSWORD"=>"NEWPASSWORD")
        end
      end

      it 'copies gitlab init example file' do
        expect(chef_run).to run_ruby_block('Copy from example gitlab init config')
      end

      describe "creating gitlab init" do
        describe "for production" do
          it 'creates gitlab default configuration file' do
            expect(chef_run).to create_template('/etc/default/gitlab').with(
              source: 'gitlab.default.erb',
              mode: 0755,
              variables: {
                app_user: 'git',
                app_root: '/home/git/gitlab'
              }
            )
          end

          # TODO Write the test that will check if notification is triggered within the ruby_block
          it 'triggers service defaults update' do
            expect(chef_run).to run_ruby_block('Copy from example gitlab init config')
            # expect(chef_run).to notify('execute[set gitlab to start on boot]').to(:run).immediately
          end
        end

        describe "for development" do
          let(:chef_run) do
            runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
            runner.node.set['gitlab']['env'] = "development"
            runner.converge("gitlab::start","gitlab::install")
          end

          it 'copies gitlab init example file' do
            expect(chef_run).to_not create_remote_file('/etc/init.d/gitlab').with(source: "file:///home/git/gitlab/lib/support/init.d/gitlab")
          end

          it 'includes phantomjs recipe' do
            expect(chef_run).to include_recipe("phantomjs::default")
          end
        end
      end

      describe "when customizing gitlab user home" do
        # Only test stuff that change when git user home is different
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['home'] = "/data/git"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a gitlab config' do
          expect(chef_run).to create_template('/data/git/gitlab/config/database.yml')
        end

        it 'updates git config' do
          resource = chef_run.find_resource(:bash, 'git config')
          expect(resource.environment).to eq('HOME' =>"/data/git")
        end

        it 'creates required directories in the rails root' do
          %w{log tmp tmp/pids tmp/sockets public/uploads}.each do |path|
            expect(chef_run).to create_directory("/data/git/gitlab/#{path}").with(
              user: 'git',
              group: 'git',
              mode: 0755
            )
          end
        end

        it 'creates satellites directory' do
         expect(chef_run).to create_directory("/data/git/gitlab-satellites")
        end

        it 'creates a unicorn config' do
          expect(chef_run).to create_template('/data/git/gitlab/config/unicorn.rb')
        end

        describe "when using mysql" do
          let(:chef_run) do
            runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
            runner.node.set['gitlab']['env'] = "production"
            runner.node.set['gitlab']['database_adapter'] = "mysql"
            runner.node.set['gitlab']['database_password'] = "datapass"
            runner.node.set['gitlab']['home'] = "/data/git"
            runner.converge("gitlab::start","gitlab::install")
          end

          it 'creates a database config' do
            expect(chef_run).to create_template('/data/git/gitlab/config/database.yml')
          end
        end

        describe "when using postgresql" do
          let(:chef_run) do
            runner = ChefSpec::Runner.new(platform: "ubuntu", version: version)
            runner.node.set['gitlab']['env'] = "production"
            runner.node.set['gitlab']['database_adapter'] = "postgresql"
            runner.node.set['gitlab']['database_password'] = "datapass"
            runner.node.set['gitlab']['home'] = "/data/git"
            runner.converge("gitlab::start","gitlab::install")
          end

          it 'creates a database config' do
            expect(chef_run).to create_template('/data/git/gitlab/config/database.yml')
          end
        end

        describe "running database setup, migrations and seed when production" do
          it 'runs db setup' do
            resource = chef_run.find_resource(:execute, 'rake db:schema:load')
            expect(resource.cwd).to eq("/data/git/gitlab")
          end

          it 'runs db migrate' do
            resource = chef_run.find_resource(:execute, 'rake db:migrate')
            expect(resource.cwd).to eq("/data/git/gitlab")
          end

          it 'runs db seed' do
            resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
            expect(resource.cwd).to eq("/data/git/gitlab")
          end
        end

        describe "creating gitlab init" do
          describe "for production" do
            it 'creates gitlab default configuration file' do
              expect(chef_run).to create_template('/etc/default/gitlab').with(
                source: 'gitlab.default.erb',
                mode: 0755,
                variables: {
                  app_user: 'git',
                  app_root: '/data/git/gitlab'
                }
              )
            end
          end
        end
      end
    end
  end

    describe "under centos" do
    ["7.0", "6.5"].each do |version|
      let(:chef_run) do
        runner = ChefSpec::Runner.new(platform: "centos", version: version)
        runner.node.set['gitlab']['env'] = "production"
        runner.converge("gitlab::start","gitlab::install")
      end

      it 'creates a gitlab config' do
        expect(chef_run).to create_template('/home/git/gitlab/config/gitlab.yml').with(
          source: 'gitlab.yml.erb',
          variables: {
            host: 'localhost',
            port: '80',
            user: 'git',
            email_from: 'gitlab@localhost',
            issue_closing_pattern: "([Cc]lose[sd]|[Ff]ixe[sd]) #(\d+)",
            max_size: '20971520',
            git_timeout: 10,
            satellites_path: '/home/git/gitlab-satellites',
            satellites_timeout: 30,
            repos_path: '/home/git/repositories',
            shell_path: '/home/git/gitlab-shell',
            signup_enabled: false,
            signin_enabled: true,
            projects_limit: 10,
            user_can_create_group: true,
            user_can_change_username: true,
            default_theme: 2,
            repository_downloads_path: 'tmp/repositories',
            oauth_enabled: false,
            oauth_block_auto_created_users: true,
            oauth_allow_single_sign_on: false,
            oauth_providers: [],
            google_analytics_id: "",
            sign_in_text: "",
            ssh_port: "22",
            default_projects_features: {
              "issues"=>true,
              "merge_requests"=>true,
              "wiki"=>true,
              "snippets"=>false,
              "visibility_level"=>"private"
              },
            webhook_timeout: 10,
            gravatar: true,
            gravatar_plain_url: "http://www.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon",
            gravatar_ssl_url: "https://secure.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon",
            ldap_config: {
              "enabled"=>false,
              "host"=>"_your_ldap_server",
              "base"=>"_the_base_where_you_search_for_users",
              "port"=>636,
              "uid"=>"sAMAccountName",
              "method"=>"ssl",
              "bind_dn"=>"_the_full_dn_of_the_user_you_will_bind_with",
              "password"=>"_the_password_of_the_bind_user",
              "allow_username_or_email_login"=>true,
              "user_filter"=>"",
              "group_base"=>"",
              "admin_group"=>"",
              "sync_ssh_keys"=>false,
              "sync_time"=>3600
            },
            ldap_servers: {},
            backup: {
              "enable"=>true,
              "cron"=>{
                "action"=>:create,
                "minute"=>0,
                "hour"=>2,
                "mailto"=>"gitlab@localhost",
                "path"=>"/usr/local/bin:/usr/bin:/bin"
              },
              "backup_keep_time"=>0,
              "backup_path"=>"tmp/backups"
            }
          }
        )
      end

      describe "creating gitlab.yml" do
        let(:template) { chef_run.template('/home/git/gitlab/config/gitlab.yml') }

        it 'triggers updating of git config' do
          expect(template).to notify('bash[git config]').to(:run).immediately
        end

        it 'updates git config' do
          resource = chef_run.find_resource(:bash, 'git config')
          expect(resource.code).to eq("    git config --global user.name \"GitLab\"\n    git config --global user.email \"gitlab@localhost\"\n    git config --global core.autocrlf input\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.environment).to eq('HOME' =>"/home/git")
        end
      end

      it 'creates required directories in the rails root' do
        %w{log tmp tmp/pids tmp/sockets public/uploads}.each do |path|
          expect(chef_run).to create_directory("/home/git/gitlab/#{path}").with(
            user: 'git',
            group: 'git',
            mode: 0755
          )
        end
      end

      it 'creates satellites directory' do
       expect(chef_run).to create_directory("/home/git/gitlab-satellites").with(
          user: 'git',
          group: 'git'
        )
      end

      it 'creates a unicorn config' do
        expect(chef_run).to create_template('/home/git/gitlab/config/unicorn.rb').with(
          source: 'unicorn.rb.erb',
          variables: {
            app_root: "/home/git/gitlab",
            unicorn_workers_number: 2,
            unicorn_timeout: 30
          }
        )
      end

      it 'copies rack_attack.rb example file' do
        expect(chef_run).to run_ruby_block('Copy from example rack attack config')
      end

      describe "creating rack_attack.rb" do

        it 'triggers uncommenting the line in application.rb' do
          # TODO Write the test that will check if notification is triggered within the ruby_block
          expect(chef_run).to run_ruby_block('Copy from example rack attack config')
          # expect(copied_file).to notify('bash[Enable rack attack in application.rb]').to(:run).immediately
        end
      end

      describe "when using mysql" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['database_adapter'] = "mysql"
          runner.node.set['gitlab']['database_password'] = "datapass"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a database config' do
          expect(chef_run).to create_template('/home/git/gitlab/config/database.yml').with(
            source: 'database.yml.mysql.erb',
            user: 'git',
            group: 'git',
            variables: {
              user: 'git',
              password: 'datapass',
              host: "localhost",
              socket: "/var/lib/mysql/mysql.sock"
            }
          )
        end
      end

      describe "when using mysql with custom server socket" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['database_adapter'] = "mysql"
          runner.node.set['gitlab']['database_password'] = "datapass"
          runner.node.set['mysql']['server']['socket'] = "/tmp/mysql.sock"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a database config' do
          expect(chef_run).to create_template('/home/git/gitlab/config/database.yml').with(
            source: 'database.yml.mysql.erb',
            user: 'git',
            group: 'git',
            variables: {
              user: 'git',
              password: 'datapass',
              host: "localhost",
              socket: "/tmp/mysql.sock"
            }
          )
        end
      end

      describe "when using postgresql" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['database_adapter'] = "postgresql"
          runner.node.set['gitlab']['database_password'] = "datapass"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a database config' do
          expect(chef_run).to create_template('/home/git/gitlab/config/database.yml').with(
            source: 'database.yml.postgresql.erb',
            user: 'git',
            group: 'git',
            variables: {
              user: 'git',
              password: 'datapass',
              host: "localhost",
              socket: nil
            }
          )
        end
      end

      describe "running database setup, migrations and seed when production" do
        it 'does not run an execute to rake db:schema:load' do
          expect(chef_run).not_to run_execute('rake db:schema:load')
        end

        it 'runs db setup' do
          resource = chef_run.find_resource(:execute, 'rake db:schema:load')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:schema:load\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"production")
        end

        it 'does not run an execute to rake db:migrate' do
          expect(chef_run).not_to run_execute('rake db:migrate')
        end

        it 'runs db migrate' do
          resource = chef_run.find_resource(:execute, 'rake db:migrate')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:migrate\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"production")
        end

        it 'does not run an execute to rake db:seed' do
          expect(chef_run).not_to run_execute('rake db:seed_fu')
        end

        it 'runs db seed' do
          resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"production", "GITLAB_ROOT_PASSWORD"=>nil)
        end
      end

      describe "when supplying root password" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['admin_root_password'] = "NEWPASSWORD"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'runs db seed' do
          resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"production", "GITLAB_ROOT_PASSWORD"=>"NEWPASSWORD")
        end
      end

      describe "running database setup, migrations and seed when development" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "development"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'runs an execute to rake db:schema:load' do
          expect(chef_run).not_to run_execute('rake db:schema:load')
        end

        it 'runs db setup for all environments' do
          resources = chef_run.find_resources(:execute).select {|n| n.name == "rake db:schema:load"}
          dev_resource = resources.first

          expect(dev_resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:schema:load\n")
          expect(dev_resource.user).to eq("git")
          expect(dev_resource.group).to eq("git")
          expect(dev_resource.cwd).to eq("/home/git/gitlab")
          expect(dev_resource.environment).to eq("RAILS_ENV"=>"development")
        end

        it 'runs an execute to rake db:migrate' do
          expect(chef_run).not_to run_execute('rake db:migrate')
        end

        it 'runs db migrate for all environments' do
          resources = chef_run.find_resources(:execute).select {|n| n.name == "rake db:migrate"}
          dev_resource = resources.first

          expect(dev_resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:migrate\n")
          expect(dev_resource.user).to eq("git")
          expect(dev_resource.group).to eq("git")
          expect(dev_resource.cwd).to eq("/home/git/gitlab")
          expect(dev_resource.environment).to eq("RAILS_ENV"=>"development")
        end

        it 'runs an execute to rake db:seed' do
          expect(chef_run).not_to run_execute('rake db:seed_fu')
        end

        it 'runs db seed' do
          resources = chef_run.find_resources(:execute).select {|n| n.name == "rake db:seed_fu"}
          dev_resource = resources.first

          expect(dev_resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(dev_resource.user).to eq("git")
          expect(dev_resource.group).to eq("git")
          expect(dev_resource.cwd).to eq("/home/git/gitlab")
          expect(dev_resource.environment).to eq("RAILS_ENV"=>"development", "GITLAB_ROOT_PASSWORD"=>nil)
        end
      end

      describe "when supplying root password in development" do
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "development"
          runner.node.set['gitlab']['admin_root_password'] = "NEWPASSWORD"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'runs db seed' do
          resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
          expect(resource.command).to eq("    PATH=\"/usr/local/bin:$PATH\"\n    bundle exec rake db:seed_fu\n")
          expect(resource.user).to eq("git")
          expect(resource.group).to eq("git")
          expect(resource.cwd).to eq("/home/git/gitlab")
          expect(resource.environment).to eq("RAILS_ENV"=>"development", "GITLAB_ROOT_PASSWORD"=>"NEWPASSWORD")
        end
      end

      it 'copies gitlab init example file' do
        expect(chef_run).to run_ruby_block('Copy from example gitlab init config')
      end

      describe "creating gitlab init" do
        describe "for production" do
          it 'creates gitlab default configuration file' do
            expect(chef_run).to create_template('/etc/default/gitlab').with(
              source: 'gitlab.default.erb',
              mode: 0755,
              variables: {
                app_user: 'git',
                app_root: '/home/git/gitlab'
              }
            )
          end

          # TODO Write the test that will check if notification is triggered within the ruby_block
          it 'triggers service defaults update' do
            expect(chef_run).to run_ruby_block('Copy from example gitlab init config')
            # expect(chef_run).to notify('execute[set gitlab to start on boot]').to(:run).immediately
          end
        end

        describe "for development" do
          let(:chef_run) do
            runner = ChefSpec::Runner.new(platform: "centos", version: version)
            runner.node.set['gitlab']['env'] = "development"
            runner.converge("gitlab::start","gitlab::install")
          end

          it 'copies gitlab init example file' do
            expect(chef_run).to run_ruby_block("Copy from example gitlab init config")
          end

          it 'includes phantomjs recipe' do
            expect(chef_run).to include_recipe("phantomjs::default")
          end
        end
      end

      describe "when customizing gitlab user home" do
        # Only test stuff that change when git user home is different
        let(:chef_run) do
          runner = ChefSpec::Runner.new(platform: "centos", version: version)
          runner.node.set['gitlab']['env'] = "production"
          runner.node.set['gitlab']['home'] = "/data/git"
          runner.converge("gitlab::start","gitlab::install")
        end

        it 'creates a gitlab config' do
          expect(chef_run).to create_template('/data/git/gitlab/config/database.yml')
        end

        it 'updates git config' do
          resource = chef_run.find_resource(:bash, 'git config')
          expect(resource.environment).to eq('HOME' =>"/data/git")
        end

        it 'creates required directories in the rails root' do
          %w{log tmp tmp/pids tmp/sockets public/uploads}.each do |path|
            expect(chef_run).to create_directory("/data/git/gitlab/#{path}").with(
              user: 'git',
              group: 'git',
              mode: 0755
            )
          end
        end

        it 'creates satellites directory' do
         expect(chef_run).to create_directory("/data/git/gitlab-satellites")
        end

        it 'creates a unicorn config' do
          expect(chef_run).to create_template('/data/git/gitlab/config/unicorn.rb')
        end

        describe "when using mysql" do
          let(:chef_run) do
            runner = ChefSpec::Runner.new(platform: "centos", version: version)
            runner.node.set['gitlab']['env'] = "production"
            runner.node.set['gitlab']['database_adapter'] = "mysql"
            runner.node.set['gitlab']['database_password'] = "datapass"
            runner.node.set['gitlab']['home'] = "/data/git"
            runner.converge("gitlab::start","gitlab::install")
          end

          it 'creates a database config' do
            expect(chef_run).to create_template('/data/git/gitlab/config/database.yml')
          end
        end

        describe "when using postgresql" do
          let(:chef_run) do
            runner = ChefSpec::Runner.new(platform: "centos", version: version)
            runner.node.set['gitlab']['env'] = "production"
            runner.node.set['gitlab']['database_adapter'] = "postgresql"
            runner.node.set['gitlab']['database_password'] = "datapass"
            runner.node.set['gitlab']['home'] = "/data/git"
            runner.converge("gitlab::start","gitlab::install")
          end

          it 'creates a database config' do
            expect(chef_run).to create_template('/data/git/gitlab/config/database.yml')
          end
        end

        describe "running database setup, migrations and seed when production" do
          it 'runs db setup' do
            resource = chef_run.find_resource(:execute, 'rake db:schema:load')
            expect(resource.cwd).to eq("/data/git/gitlab")
          end

          it 'runs db migrate' do
            resource = chef_run.find_resource(:execute, 'rake db:migrate')
            expect(resource.cwd).to eq("/data/git/gitlab")
          end

          it 'runs db seed' do
            resource = chef_run.find_resource(:execute, 'rake db:seed_fu')
            expect(resource.cwd).to eq("/data/git/gitlab")
          end
        end

        describe "creating gitlab init" do
          describe "for production" do
            it 'creates gitlab default configuration file' do
              expect(chef_run).to create_template('/etc/default/gitlab').with(
                source: 'gitlab.default.erb',
                mode: 0755,
                variables: {
                  app_user: 'git',
                  app_root: '/data/git/gitlab'
                }
              )
            end
          end
        end
      end
    end
  end
end
