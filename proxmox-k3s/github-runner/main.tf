terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
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

resource "proxmox_vm_qemu" "github_runner" {
  name        = "github-runner"
  target_node = var.target_node
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

  disk {
    slot    = "scsi0"
    storage = "local-zfs"
    size    = "120G"
  }

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
  ipconfig0  = "ip=${var.runner_ip}/24,gw=${var.gateway}"
  nameserver = "8.8.8.8 1.1.1.1"

  agent  = 1
  onboot = true

  lifecycle {
    ignore_changes = [network]
  }

  provisioner "file" {
    content = templatefile("${path.module}/scripts/setup-runner.sh.tpl", {
      runner_version = var.runner_version
      github_pat     = var.github_pat
      github_repo    = var.github_repo
      runner_name    = var.runner_name
    })
    destination = "/home/ubuntu/setup-runner.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      password    = var.vm_password
      private_key = file("~/.ssh/id_rsa_k3s")
      host        = var.runner_ip
      timeout     = "15m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/setup-runner.sh",
      "bash /home/ubuntu/setup-runner.sh 2>&1 | tee /home/ubuntu/setup-runner.log",
      "echo 'Provisioning complete'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      password    = var.vm_password
      private_key = file("~/.ssh/id_rsa_k3s")
      host        = var.runner_ip
      timeout     = "15m"
    }
  }
}
