terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "k3s_master" {
  name        = "k3s-master-1"
  target_node = "master"
  clone       = "ubuntu-image"
  full_clone  = true

  os_type = "cloud-init"

  cpu {
    cores   = 2
    sockets = 1
    type    = "kvm64"
  }

  memory = 16384
  scsihw = "virtio-scsi-pci"

  # Cloud-init drive only (let scsi0 come from clone)
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-zfs"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot     = "order=scsi0"
  bootdisk = "scsi0"

  # Cloud-init config
  ciuser     = "ubuntu"
  sshkeys    = var.ssh_pub_key
  ipconfig0  = "ip=192.168.4.180/24,gw=192.168.4.1"
  nameserver = "8.8.8.8 8.8.4.4" # Fix DNS!

  agent  = 1
  onboot = true

  lifecycle {
    ignore_changes = [
      network
    ]
  }

  # Install K3s server
  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 2; done",
      "sleep 5",
      "curl -sfL https://get.k3s.io -o install.sh || wget -O install.sh https://get.k3s.io",
      "sudo sh install.sh --write-kubeconfig-mode 644"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa_k3s") # Use your key path
      host        = "192.168.4.180"
      timeout     = "10m"
    }
  }
}

# Output the master token for workers
output "k3s_token" {
  value     = "Run: ssh ubuntu@192.168.4.180 'sudo cat /var/lib/rancher/k3s/server/node-token'"
  sensitive = false
}
