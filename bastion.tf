# Recurso para obter o próximo endereço IP disponível
data "external" "next_ip" {
  program = var.os_type == "windows" ? [
    "powershell", "-Command", <<-EOF
    $network = "172.16.20.0/24"
    $ips_in_use = arp -a | Select-String -Pattern "172.16.20." | ForEach-Object { $_.ToString().Split()[1].Trim("()") }
    $ip_range = 1..254 | ForEach-Object { "172.16.20.$_" }
    $available_ips = $ip_range | Where-Object { $_ -notin $ips_in_use }
    $output = @{ ip = $available_ips[0] } | ConvertTo-Json
    Write-Output $output
    EOF
  ] : [
    "bash", "-c", <<-EOF
    network="172.16.20.0/24"
    ips_in_use=$(arp -a | grep "172.16.20." | awk '{print $2}' | tr -d '()')
    ip_range=$(seq 1 254 | awk '{print "172.16.20."$1}')
    for ip in $ip_range; do
      if ! echo "$ips_in_use" | grep -q "$ip"; then
        echo "{ \\"ip\\": \\"$ip\\" }"
        break
      fi
    done
    EOF
  ]
}

# Gerar chave privada e chave pública usando o provedor tls
resource "tls_private_key" "generated_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Locals para armazenar conteúdo da chave pública e caminho da chave privada
locals {
  private_key_path   = "${path.module}/terraform"
  public_key_content = tls_private_key.generated_key.public_key_openssh
}


# Recurso para criar a VM no Proxmox
resource "proxmox_vm_qemu" "bastion" {
  name        = "VM"  # Nome da VM
  desc        = "Nova VM clonada"  # Descrição da VM
  target_node = var.proxmox_host   # Nó de destino do Proxmox

  clone       = var.template_name  # Nome do template para criação da VM

  agent       = 0  # O agente QEMU está desativado inicialmente

  os_type     = "cloud-init"  # Tipo de sistema operacional da imagem clone
  cores       = 2  # Número de núcleos da CPU
  sockets     = 2  # Número de sockets da CPU
  cpu         = "host"  # Tipo de CPU
  memory      = 4096  # Quantidade de memória alocada
  onboot      = true  # Iniciar a VM na inicialização do host
  scsihw      = "virtio-scsi-pci"  # Tipo de hardware SCSI
  bootdisk    = "scsi0"  # Disco de boot SCSI

  # Configuração do disco
  disk {
    size      = "30G"
    type      = "scsi"
    storage   = "local"
    iothread  = 0
    ssd       = 1
  }

  # Configuração de rede
  network {
    model     = "virtio"
    bridge    = "vmbr0"
    tag       = 20
  }

  # Configuração do IP
  ipconfig0   = "ip=${data.external.next_ip.result["ip"]}/24,gw=172.16.20.1"
  nameserver  = "172.16.20.1"

  serial {
    id        = 0
    type      = "socket"
  }

  # Chave SSH configurada com variável
  sshkeys = local.public_key_content

  # Provisionador remoto para execução de comandos na VM
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo apt install -y net-tools qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent",
      "echo Done!"
    ]

    connection {
      host        = "${data.external.next_ip.result["ip"]}"
      type        = "ssh"
      user        = "anakin"
      private_key = file(local.private_key_path)
    }
  }

  # Provisionador local para monitoramento da tarefa de clonagem
  provisioner "local-exec" {
    command = "python3 script_monitor_task.py TASK_ID"
  }
}

# Recurso nulo para habilitar o agente QEMU após a instalação
resource "null_resource" "enable_qemu_agent" {
  depends_on = [proxmox_vm_qemu.bastion]

  provisioner "local-exec" {
    command = <<-EOF
    pvesh set /nodes/${var.proxmox_host}/qemu/${proxmox_vm_qemu.bastion.vmid}/config -agent 1
    EOF
  }
}

# Recurso nulo para execução de playbook Ansible após a criação da VM
resource "null_resource" "bastion-ansible" {
  depends_on = [null_resource.enable_qemu_agent]

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.ansible_user} -l bastion -i ../home-deploy/inventory --private-key ${local.private_key_path} -e 'pub_key=${local.public_key_content}' --ssh-extra-args '-o UserKnownHostsFile=/dev/null' ../home-deploy/main.yml"
  }
}
