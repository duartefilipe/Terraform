terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.9.11"  # Verifique se esta é a versão mais recente
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.100.37:8006/api2/json"
  pm_user         = "root@pam"          # Use o seu usuário Proxmox
  pm_password     = "Eunaoseiasenha22!"  # Use a sua senha Proxmox
  pm_tls_insecure = true                # Apenas para ignorar problemas com SSL
}

resource "proxmox_vm_qemu" "ubuntu_vm" {
  name        = "terraform"
  target_node = "anakin"  # Nome do seu nó Proxmox

  iso         = "local:iso/ubuntu-24.04-live-server-amd64.iso"

  os_type     = "cloud-init"
  cores       = 2
  sockets     = 1
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  disk {
    type      = "scsi"
    storage   = "local"
    size      = "50G"
  }

  network {
    model     = "virtio"
    bridge    = "vmbr0"
  }

  boot = "cdn" 

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "export ANSIBLE_HOST_KEY_CHECKING=False",
      "curl -o /tmp/playbook.yml -L https://raw.githubusercontent.com/duartefilipe/Automacoes/main/Ansible/playbook.yml?token=GHSAT0AAAAAACRPXEMQXCZZG7TDEDBRYYGCZTRUQJA",
      "apt-get update && apt-get install -y ansible",
      "VM_IP=$(qm guest exec ${self.id} -- ip -4 addr show eth0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}')",
      "echo $VM_IP > /tmp/ip_address.txt",
      "ansible-playbook /tmp/playbook.yml"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      password    = "Eunaoseiasenha22!"
      host        = "192.168.100.37"  # Substitua pelo IP correto do seu Proxmox
    }
  }
}

output "vm_ip_address" {
  value = try(file("${path.module}/ip_address.txt"), null)
}
