variable "proxmox_api_url" {}
variable "proxmox_user" {}

variable "proxmox_password" {
  sensitive = true
}

variable "target_node" {
  default = "worker3"
}

variable "vm_password" {
  sensitive = true
}

variable "ssh_pub_key" {}

variable "gateway" {
  default = "192.168.4.1"
}

variable "runner_ip" {
  default = "192.168.4.183"
}

variable "runner_name" {
  default = "homelab-runner"
}

variable "runner_version" {
  default = "2.319.1"
}

# GitHub repo in "owner/repo" format, e.g. "kevinroccanova/k3s"
variable "github_repo" {}

# GitHub PAT with repo scope (used once to get a registration token)
variable "github_pat" {
  sensitive = true
}
