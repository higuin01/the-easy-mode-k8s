Vagrant.configure("2") do |config|
    (1..1).each do |i|
        config.vm.synced_folder "./scripts", "/root/sync-scripts", 
            type: "virtualbox",        # Tipo de provedor (VirtualBox por padrão)
            owner: "vagrant",          # Dono dentro da VM
            group: "vagrant",          # Grupo dentro da VM
            mount_options: ["dmode=775,fmode=664"]  # Permissões
        config.vm.define "master-#{i}" do |k8s|
            k8s.vm.box = "ubuntu/jammy64"
            k8s.vm.hostname = "master-#{i}"
            k8s.vm.network "private_network", ip: "192.168.56.1#{i}"

            k8s.ssh.insert_key = false
            k8s.ssh.private_key_path = ['~/.vagrant.d/insecure_private_key', '~/.ssh/id_rsa']

            k8s.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "~/.ssh/authorized_keys"
            k8s.vm.provision "shell", inline: <<-SHELL
            sudo cp /home/vagrant/.ssh/authorized_keys /root/.ssh/authorized_keys
            echo 'PermitRootLogin yes' | sudo tee -a /etc/ssh/sshd_config
            sudo systemctl restart sshd
            SHELL
            


            k8s.vm.provider "virtualbox" do |vb|
              vb.gui = false
              vb.cpus = 2
              vb.memory = "3048"
            end
        end
    end

    (0..2).each do |i|
        config.vm.define "worker-#{i}" do |k8s|
            k8s.vm.box = "ubuntu/jammy64"
            k8s.vm.hostname = "worker-#{i}"
            k8s.vm.network "private_network", ip: "192.168.56.2#{i}"

            k8s.ssh.insert_key = false
            k8s.ssh.private_key_path = ['~/.vagrant.d/insecure_private_key', '~/.ssh/id_rsa']
            
            k8s.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "~/.ssh/authorized_keys"
            k8s.vm.provision "shell", inline: <<-SHELL
            sudo cp /home/vagrant/.ssh/authorized_keys /root/.ssh/authorized_keys
            echo 'PermitRootLogin yes' | sudo tee -a /etc/ssh/sshd_config
            sudo systemctl restart sshd
            SHELL

            k8s.vm.provider "virtualbox" do |vb|
              vb.gui = false
              vb.cpus = 2
              vb.memory = "2500"
            end
        end
    end
end
#Dh${1q=kMr45TS9@1#