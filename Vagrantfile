VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define :trickster do |trickster_config|
    trickster_config.vm.box = "bento/ubuntu-18.04"
    trickster_config.vm.hostname = "trickster.example.com"
    trickster_config.vm.network "private_network", ip: "192.168.20.10"
    trickster_config.vm.provision "shell", path: "configure_node.sh"
    config.vm.provider "virtualbox" do |v|
      v.memory = 2048
      v.cpus = 2
    end
  end
end
