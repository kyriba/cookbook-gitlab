require 'spec_helper'

describe "gitlab::packages" do
  let(:chef_run) { ChefSpec::Runner.new.converge("gitlab::packages") }


  describe "under ubuntu" do
    ["14.04", "12.04", "10.04"].each do |version|
      let(:chef_run) { ChefSpec::Runner.new(platform: "ubuntu", version: version).converge("gitlab::packages") }

      before do
        # stubbing git commands because packages recipe requires gitlab::git
        stub_command("test -f #{Chef::Config['file_cache_path']}/git-2.0.0.zip").and_return(true)
        stub_command("git --version | grep 2.0.0").and_return(true)
        stub_command("git --version >/dev/null").and_return(true)
      end

      it "includes recipes from external cookbooks" do
        expect(chef_run).to include_recipe("apt::default")
        expect(chef_run).to_not include_recipe("yum::epel")
        expect(chef_run).to include_recipe("gitlab::git")
      end

      it "installs all default packages" do
        packages = chef_run.node['gitlab']['packages']
        packages.each do |pkg|
          expect(chef_run).to install_package(pkg)
        end
      end

      it "should not install package git" do
        expect(chef_run).to_not install_package("git")
      end
    end
  end

  describe "under centos" do
    ["5.8", "6.4"].each do |version|
      let(:chef_run) { ChefSpec::Runner.new(platform: "centos", version: version).converge("gitlab::packages") }

      before do
        # stubbing git commands because packages recipe requires gitlab::git
        stub_command("test -f #{Chef::Config['file_cache_path']}/git-2.0.0.zip").and_return(true)
        stub_command("git --version | grep 2.0.0").and_return(true)
        stub_command("git --version >/dev/null").and_return(true)
      end

      it "includes recipes from external cookbooks" do
        expect(chef_run).to_not include_recipe("apt::default")
        expect(chef_run).to include_recipe("yum-epel::default")
        expect(chef_run).to include_recipe("gitlab::git")
      end

      it "installs all default packages" do
        packages = chef_run.node['gitlab']['packages']
        packages.each do |pkg|
          expect(chef_run).to install_package(pkg)
        end
      end

      it "should not install package git" do
        expect(chef_run).to_not install_package("git")
      end
    end
  end
end
