# K3s Kubernetes Cluster on Proxmox

Automated deployment of a production-ready K3s Kubernetes cluster on Proxmox using Terraform.

## Architecture

- **1 Master Node**: K3s control plane (192.168.4.180)
- **2 Worker Nodes**: K3s agents for workload scheduling (192.168.4.181-182)
- **Platform**: Proxmox VE with Ubuntu 22.04 LTS templates
- **Network**: Static IPs on 192.168.4.0/24 network
- **Storage**: Local ZFS on Proxmox nodes

## Prerequisites

### On Proxmox

1. **Ubuntu Cloud Image Template** (ID 400)
   - Ubuntu 22.04 LTS cloud image
   - Cloud-init configured
   - Located on `local-zfs` storage
   - Named `ubuntu-image`

2. **Proxmox Nodes**
   - `master` node for control plane
   - `worker3` node for worker VMs

3. **Network Configuration**
   - Bridge: `vmbr0`
   - Gateway: `192.168.4.1`
   - DNS: Configured for external access

### On Your Local Machine

1. **Terraform** >= 1.0
   ```bash
   brew install terraform  # macOS
   ```

2. **kubectl** (for cluster management)
   ```bash
   brew install kubectl  # macOS
   ```

3. **SSH Key Pair**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_k3s
   ```

## Setup Instructions

### 1. Clone and Configure

```bash
# Clone the repository
git clone <your-repo>
cd <repo-directory>

# Copy the example tfvars file
cp terraform.tfvars.example terraform.tfvars

# Edit with your actual values
nano terraform.tfvars
```

### 2. Configure Variables

Edit `terraform.tfvars` with your settings:

```hcl
proxmox_api_url  = "https://your-proxmox-ip:8006/api2/json"
proxmox_user     = "root@pam"
proxmox_password = "your-proxmox-password"

vm_password      = "your-vm-password"
ssh_pub_key      = "ssh-rsa AAAA... your-public-key"
ssh_private_key  = "~/.ssh/id_rsa_k3s"

master_ip = "192.168.4.180"
gateway   = "192.168.4.1"

workers = {
  worker1 = { name = "k3s-worker-1", ip = "192.168.4.181", node = "worker3" }
  worker2 = { name = "k3s-worker-2", ip = "192.168.4.182", node = "worker3" }
}
```

### 3. Deploy the Cluster

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the master node
cd master
terraform apply

# Wait for master to complete, then get the K3s token
ssh ubuntu@192.168.4.180 'sudo cat /var/lib/rancher/k3s/server/node-token'

# Add the token to your tfvars
echo 'k3s_token = "K10xxxxx::server:xxxxx"' >> ../workers/terraform.tfvars

# Deploy the worker nodes
cd ../workers
terraform apply
```

### 4. Configure kubectl Access

```bash
# SSH to master and get kubeconfig
ssh ubuntu@192.168.4.180
sudo cat /var/lib/rancher/k3s/server/cred/admin.kubeconfig

# On your local machine, create ~/.kube/config
mkdir -p ~/.kube
nano ~/.kube/config

# Paste the kubeconfig and change the server line:
# FROM: server: https://127.0.0.1:6443
# TO:   server: https://192.168.4.180:6443

# Test access
kubectl get nodes
```

Expected output:
```
NAME           STATUS   ROLES           AGE   VERSION
k3s-master-1   Ready    control-plane   10m   v1.34.3+k3s1
k3s-worker-1   Ready    <none>          5m    v1.34.3+k3s1
k3s-worker-2   Ready    <none>          5m    v1.34.3+k3s1
```

## Project Structure

```
.
├── master/
│   ├── main.tf              # Master node configuration
│   ├── variables.tf         # Variable definitions
│   └── terraform.tfvars     # Master-specific values (gitignored)
├── workers/
│   ├── main.tf              # Worker nodes configuration
│   ├── variables.tf         # Variable definitions
│   ├── cloud-init/
│   │   └── k3s-worker.yaml  # Worker cloud-init template
│   └── terraform.tfvars     # Worker-specific values (gitignored)
├── .gitignore
├── terraform.tfvars.example # Example configuration
└── README.md
```

## Common Operations

### Scale Workers

Edit `workers/terraform.tfvars` and add a new worker:

```hcl
workers = {
  worker1 = { name = "k3s-worker-1", ip = "192.168.4.181", node = "worker3" }
  worker2 = { name = "k3s-worker-2", ip = "192.168.4.182", node = "worker3" }
  worker3 = { name = "k3s-worker-3", ip = "192.168.4.183", node = "worker3" }
}
```

Then apply:
```bash
cd workers
terraform apply
```

### Add Worker Role Labels

```bash
kubectl label node k3s-worker-1 node-role.kubernetes.io/worker=worker
kubectl label node k3s-worker-2 node-role.kubernetes.io/worker=worker
```

### Access Node via SSH

```bash
ssh ubuntu@192.168.4.180  # Master
ssh ubuntu@192.168.4.181  # Worker 1
ssh ubuntu@192.168.4.182  # Worker 2
```

### Check Cluster Health

```bash
# Node status
kubectl get nodes -o wide

# System pods
kubectl get pods -n kube-system

# All resources
kubectl get all -A
```

### Deploy a Test Application

```bash
# Create deployment
kubectl create deployment nginx --image=nginx

# Expose as NodePort
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the port
kubectl get svc nginx

# Access via any node IP
curl http://192.168.4.180:<NodePort>

# Clean up
kubectl delete deployment nginx
kubectl delete service nginx
```

## Troubleshooting

### DNS Issues on Workers

If pods can't pull images:

```bash
# SSH to worker
ssh ubuntu@192.168.4.181

# Check DNS
cat /etc/resolv.conf
nslookup registry-1.docker.io

# Fix DNS if needed
sudo nano /etc/resolv.conf
# Add: nameserver 8.8.8.8

sudo systemctl restart containerd
```

### Worker Not Joining Cluster

```bash
# Check K3s agent status
sudo systemctl status k3s-agent

# Check logs
sudo journalctl -u k3s-agent -n 50

# Verify token and master IP
sudo cat /etc/systemd/system/k3s-agent.service.env
```

### Recreate a Node

```bash
# Remove from cluster first
kubectl delete node k3s-worker-1

# Destroy and recreate with Terraform
cd workers
terraform destroy -target=proxmox_vm_qemu.k3s_worker[\"worker1\"]
terraform apply
```

### Image Pull Errors

```bash
# Check pod events
kubectl describe pod <pod-name>

# Common fixes:
# 1. DNS issues (see above)
# 2. Network connectivity - verify internet access on workers
# 3. Wait - sometimes temporary, retry after a minute
```

## VM Specifications

### Master Node
- **CPU**: 2 cores, 1 socket
- **Memory**: 16 GB
- **Disk**: 120 GB (cloned from template)
- **Network**: Static IP via cloud-init
- **Services**: K3s server, etcd

### Worker Nodes
- **CPU**: 2 cores, 1 socket
- **Memory**: 16 GB
- **Disk**: 120 GB (cloned from template)
- **Network**: Static IP via cloud-init
- **Services**: K3s agent, containerd

## Network Configuration

- **Cluster Network**: 192.168.4.0/24
- **Master IP**: 192.168.4.180
- **Worker IPs**: 192.168.4.181-182
- **Gateway**: 192.168.4.1
- **DNS**: 8.8.8.8, 8.8.4.4
- **K3s API Port**: 6443
- **NodePort Range**: 30000-32767

## Security Considerations

- SSH key authentication only (password auth disabled)
- Firewall rules on nodes (if using ufw, allow 6443 and NodePort range)
- K3s token should be kept secret (in terraform.tfvars, which is gitignored)
- Consider using cert-manager for TLS
- Keep kubeconfig secure (chmod 600 ~/.kube/config)

## Next Steps

- [ ] Install monitoring stack (Prometheus + Grafana)
- [ ] Set up ingress controller (Traefik included by default)
- [ ] Configure persistent storage (Longhorn or local-path)
- [ ] Implement GitOps with ArgoCD or Flux
- [ ] Set up automated backups
- [ ] Configure network policies
- [ ] Add cert-manager for TLS

## Resources

- [K3s Documentation](https://docs.k3s.io/)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)

## License

MIT

## Contributing

Pull requests welcome! Please ensure:
- No secrets in commits
- Test changes on a non-production cluster first
- Update documentation for any configuration changes