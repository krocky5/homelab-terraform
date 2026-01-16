variable "proxmox_api_url" {}
variable "proxmox_user" {}
variable "proxmox_password" {}
variable "vm_password" {}
variable "ssh_pub_key" {}
variable "gateway" {}

variable "master_ip" {}
variable "k3s_token" {}

variable "workers" {
  type = map(object({
    name = string
    ip   = string
    node = string
  }))
}
