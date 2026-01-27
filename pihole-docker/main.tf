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

resource "proxmox_vm_qemu" "pihole" {
  name        = "pihole-docker"
  target_node = var.target_node
  clone       = var.template_name
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
  # Cloud-init drive only (let scsi0 come from clone)
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.storage_pool
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
  cipassword = var.vm_password
  sshkeys    = var.ssh_pub_key
  ipconfig0  = "ip=${var.pihole_ip}/24,gw=${var.gateway}"
  nameserver = var.nameserver

  agent  = 1
  onboot = true

  lifecycle {
    ignore_changes = [
      network
    ]
  }

  # Install Docker and setup PiHole
  provisioner "file" {
    content = templatefile("${path.module}/docker-compose.yml", {
      TZ          = "America/New_York"
      WEBPASSWORD = var.pihole_password
      PIHOLE_IP   = var.pihole_ip
    })
    destination = "/home/${var.vm_user}/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = var.vm_user
      password    = var.vm_password
      private_key = file(var.ssh_private_key_path)
      host        = var.pihole_ip
      timeout     = "10m"
    }
  }

  # Install and start
  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 2; done",
      "sleep 10",
      "if ! command -v docker &> /dev/null; then curl -fsSL https://get.docker.com | sudo sh; fi",
      "sudo usermod -aG docker ${var.vm_user}",
      "sudo systemctl stop systemd-resolved",
      "sudo systemctl disable systemd-resolved",
      "sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf",
      "sudo rm -f /etc/resolv.conf",
      "echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf",
      "mkdir -p ~/pihole/etc-pihole ~/pihole/etc-dnsmasq.d",
      "mv ~/docker-compose.yml ~/pihole/",
      "cd ~/pihole && sudo docker compose up -d"
    ]

    connection {
      type        = "ssh"
      user        = var.vm_user
      password    = var.vm_password
      private_key = file(var.ssh_private_key_path)
      host        = var.pihole_ip
      timeout     = "10m"
    }
  }
}
