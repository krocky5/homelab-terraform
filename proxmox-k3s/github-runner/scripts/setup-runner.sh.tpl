#!/bin/bash
set -e

echo "==> Waiting for cloud-init..."
until [ -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 2; done
sleep 10

echo "==> Installing dependencies..."
sudo apt-get update -q
sudo apt-get install -y jq unzip curl wget

echo "==> Installing Docker..."
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

echo "==> Installing kubectl..."
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "==> Installing kubeseal..."
wget -q https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm -f kubeseal kubeseal-0.24.0-linux-amd64.tar.gz

echo "==> Installing Vault CLI..."
wget -q https://releases.hashicorp.com/vault/1.15.6/vault_1.15.6_linux_amd64.zip
unzip -q vault_1.15.6_linux_amd64.zip
sudo mv vault /usr/local/bin/
rm -f vault_1.15.6_linux_amd64.zip

echo "==> Downloading GitHub Actions runner v${runner_version}..."
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

curl -o actions-runner-linux-x64-${runner_version}.tar.gz -L \
  "https://github.com/actions/runner/releases/download/v${runner_version}/actions-runner-linux-x64-${runner_version}.tar.gz"
tar xzf ./actions-runner-linux-x64-${runner_version}.tar.gz
rm -f actions-runner-linux-x64-${runner_version}.tar.gz

echo "==> Getting registration token from GitHub..."
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${github_pat}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${github_repo}/actions/runners/registration-token" | jq -r .token)

if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
  echo "ERROR: Failed to get registration token. Check your PAT and repo name (format: owner/repo)."
  exit 1
fi

echo "==> Configuring runner..."
./config.sh \
  --url "https://github.com/${github_repo}" \
  --token "$REG_TOKEN" \
  --unattended \
  --labels "self-hosted,homelab,linux,x64" \
  --name "${runner_name}" \
  --replace

echo "==> Installing runner as systemd service..."
sudo ./svc.sh install ubuntu
sudo ./svc.sh start

echo "==> Done! Runner status:"
sudo ./svc.sh status
