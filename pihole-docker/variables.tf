variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox API user"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Proxmox node to deploy on"
  type        = string
  default     = "master"
}

variable "template_name" {
  description = "Name of the VM template to clone"
  type        = string
  default     = "ubuntu-image"
}

variable "storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-zfs"
}

variable "vm_user" {
  description = "VM user for SSH access"
  type        = string
  default     = "ubuntu"
}

variable "vm_password" {
  description = "VM password for SSH access"
  type        = string
  sensitive   = true
}

variable "ssh_pub_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa_k3s"
}

variable "pihole_ip" {
  description = "Static IP address for PiHole"
  type        = string
  default     = "192.168.4.10"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.4.1"
}

variable "nameserver" {
  description = "Nameserver for initial setup (will be changed to PiHole after)"
  type        = string
  default     = "8.8.8.8 1.1.1.1"
}

variable "pihole_password" {
  description = "PiHole web interface password"
  type        = string
  sensitive   = true
}

variable "timezone" {
  description = "Timezone for PiHole"
  type        = string
  default     = "America/New_York"
}
