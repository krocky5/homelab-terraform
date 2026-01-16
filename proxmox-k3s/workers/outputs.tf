output "worker_ips" {
  value = [for w in proxmox_vm_qemu.k3s_worker : w.id]
}
