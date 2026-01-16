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

resource "proxmox_vm_qemu" "k3s_worker" {
  for_each    = var.workers
  name        = each.value.name
  target_node = each.value.node
  clone       = "ubuntu-worker"
  full_clone  = true

  os_type = "cloud-init"

  cpu {
    cores   = 2
    sockets = 1
    type    = "kvm64"
  }

  memory = 16384
  scsihw = "virtio-scsi-pci"

  disk {
    slot    = "scsi0"
    storage = "local-zfs"
    size    = "120G"
  }

  # Cloud-init disk: ensures IDE2 is always attached
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

  ciuser     = "ubuntu"
  cipassword = var.vm_password
  sshkeys    = var.ssh_pub_key
  ipconfig0  = "ip=${each.value.ip}/24,gw=${var.gateway}"
  nameserver = "8.8.8.8 1.1.1.1"

  agent  = 1
  onboot = true


  provisioner "remote-exec" {
    inline = [
      "until nslookup get.k3s.io; do echo 'Waiting for DNS...'; sleep 5; done",
      "curl -sfL https://get.k3s.io -o install.sh || wget -O install.sh https://get.k3s.io",
      "sudo K3S_URL=https://${var.master_ip}:6443 K3S_TOKEN=${var.k3s_token} sh install.sh --node-name ${each.value.name}"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      password    = var.vm_password
      private_key = file("~/.ssh/id_rsa_k3s")
      host        = each.value.ip
      timeout     = "10m"
    }
  }
}
