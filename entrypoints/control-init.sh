#!/bin/bash
# entrypoints/control-init.sh

echo "Initializing Ansible Control Node..."

# 1. Setup SSH Keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [ ! -f /ssh-shared/id_rsa ]; then
  echo "SSH keys not found in shared volume. Generating a new pair..."
  ssh-keygen -t rsa -b 2048 -N "" -f /ssh-shared/id_rsa
  cp /ssh-shared/id_rsa.pub /ssh-shared/authorized_keys
  echo "New SSH keys generated and shared."
else
  echo "Found existing SSH keys in shared volume. Reusing them..."
fi

# Copy key to root's .ssh directory
cp /ssh-shared/id_rsa /root/.ssh/id_rsa
cp /ssh-shared/id_rsa.pub /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub

# Create local ssh config to disable strict host checking inside container
cat <<EOF > /root/.ssh/config
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
chmod 600 /root/.ssh/config

# 2. Setup Kubectl Config (pointing to K3s)
mkdir -p /root/.kube

# Run a background loop to keep checking for kubeconfig.yaml, copy it, and patch it
(
  while true; do
    if [ -f /shared/kubeconfig.yaml ]; then
      # Only copy/patch if kubeconfig has changed or not yet copied
      if [ ! -f /root/.kube/config ] || [ /shared/kubeconfig.yaml -nt /root/.kube/config ]; then
        echo "Updating kubeconfig with container DNS..."
        cp /shared/kubeconfig.yaml /root/.kube/config
        sed -i 's/127.0.0.1/k3s/g' /root/.kube/config
        chmod 600 /root/.kube/config
        echo "Kubeconfig updated successfully."
      fi
    fi
    sleep 5
  done
) &

echo "Ansible Control Node initialization complete. Keeping container alive..."

# Keep the container running
exec tail -f /dev/null
