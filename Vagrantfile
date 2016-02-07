VAGRANTFILE_API_VERSION = "2"
BOX = "ubuntu/trusty64"

base_dir = File.expand_path(File.dirname(__FILE__))

# Cluster, VM and network settings
NETWORK_SUBNET = "192.168.1"
NETWORK_DOMAIN = "lan"
NUM_MASTER_LDAPS = 1
NUM_SLAVE_LDAPS = 1
MASTER_LDAP_IPS_START = 50
SLAVE_LDAP_IPS_START = 60
MASTER_LDAP_MEMORY = 512
SLAVE_LDAP_MEMORY = 512
MASTER_LDAP_CPU = 1
SLAVE_LDAP_CPU = 1

ansible_provision = proc do |ansible|
  ansible.playbook = 'site.yml'
  # Note: Can't do ranges like mon[0-2] in groups because
  # these aren't supported by Vagrant, see
  # https://github.com/mitchellh/vagrant/issues/3539
  ansible.groups = {
    'master_ldaps' => (0..NUM_MASTER_LDAPS - 1).map { |j| "mldap#{j}.#{NETWORK_DOMAIN}" },
    'slave_ldaps'  => (0..NUM_SLAVE_LDAPS - 1).map { |j| "sldap#{j}.#{NETWORK_DOMAIN}" },
    'all:children' => ["master_ldaps", "slave_ldaps"],
  }
  
  ansible.verbose = "v"

  # In a production deployment, these should be secret
  ansible.extra_vars = {
    cluster_network: "#{NETWORK_SUBNET}.0/24",
  }
  ansible.limit = 'all'
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.ssh.insert_key = false
  config.vm.box = BOX

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :machine
    config.cache.enable :apt
  end
  
  (0..NUM_MASTER_LDAPS - 1).each do |i|
    config.vm.define "mldap#{i}.#{NETWORK_DOMAIN}" do |de|
      de.vm.hostname = "mldap#{i}.#{NETWORK_DOMAIN}"
      de.vm.network :private_network, ip: "#{NETWORK_SUBNET}.#{MASTER_LDAP_IPS_START + i}"

      # Virtualbox
      de.vm.provider :virtualbox do |vb|
        vb.customize ['modifyvm', :id, '--memory', "#{MASTER_LDAP_MEMORY}"]
        vb.customize ['modifyvm', :id, '--cpus', "#{MASTER_LDAP_CPU}"]
      end

      # VMware
      de.vm.provider :vmware_fusion do |v|
        v.vmx['memsize'] = "#{MASTER_LDAP_MEMORY}"
      end

      # Libvirt
      de.vm.provider :libvirt do |lv|
        lv.memory = MASTER_LDAP_MEMORY
      end
    end
  end
  
  (0..NUM_SLAVE_LDAPS - 1).each do |i|
    config.vm.define "sldap#{i}.#{NETWORK_DOMAIN}" do |dr|
      dr.vm.hostname = "sldap#{i}.#{NETWORK_DOMAIN}"
      dr.vm.network :private_network, ip: "#{NETWORK_SUBNET}.#{SLAVE_LDAP_IPS_START + i}"

      # Virtualbox
      dr.vm.provider :virtualbox do |vb|
        vb.customize ['modifyvm', :id, '--memory', "#{SLAVE_LDAP_MEMORY}"]
        vb.customize ['modifyvm', :id, '--cpus', "#{SLAVE_LDAP_CPU}"]
      end

      # VMware
      dr.vm.provider :vmware_fusion do |v|
        v.vmx['memsize'] = "#{SLAVE_LDAP_MEMORY}"
      end

      # Libvirt
      dr.vm.provider :libvirt do |lv|
        lv.memory = SLAVE_LDAP_MEMORY
      end
      
      # Run the provisioner after the last machine comes up
      dr.vm.provision 'ansible', &ansible_provision if i == (NUM_SLAVE_LDAPS - 1)
    end
  end
end