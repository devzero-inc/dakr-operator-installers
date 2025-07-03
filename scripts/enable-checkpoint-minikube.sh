#!/bin/bash

# Script to enable container checkpointing in Minikube
# This script needs to be run from the host machine, not inside Minikube

set -e

echo "Configuring containerd in Minikube for checkpointing..."
SCRIPT=$(mktemp -t dakr-enable-checkpoint)
trap "rm $SCRIPT" EXIT

# Connect to Minikube
cat <<'EOF' > "$SCRIPT"
  # Make a backup of the containerd config
  sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.backup

  # Check if containerd is using the default config or a custom one
  if [ ! -s /etc/containerd/config.toml ]; then
    echo "Creating new containerd config..."
    sudo mkdir -p /etc/containerd/
    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
  fi

  # Modify the containerd configuration to enable checkpointing
  echo "Modifying containerd config to enable checkpoint/restore..."
  
  # Check if the config already contains checkpoint settings
  if ! grep -q "enable_checkpoint" /etc/containerd/config.toml; then
    # Add checkpoint configuration
    # For containerd 1.6+
    sudo sed -i '/\[plugins."io.containerd.grpc.v1.cri".containerd\]/a \ \ enable_checkpoint = true\n \ enable_criu_support = true' /etc/containerd/config.toml
    
    # For containerd 1.5 and earlier (fallback if the above doesn't apply)
    if ! grep -q "enable_checkpoint" /etc/containerd/config.toml; then
      sudo sed -i '/\[plugins.cri.containerd\]/a \ \ enable_checkpoint = true\n \ enable_criu_support = true' /etc/containerd/config.toml
    fi
  else
    echo "Checkpoint configuration already exists."
  fi

  # Restart containerd
  echo "Restarting containerd..."
  sudo systemctl restart containerd
EOF

minikube cp "$SCRIPT" /usr/local/bin/enable-checkpoint-minikube.sh 
minikube ssh "sudo chmod +x /usr/local/bin/enable-checkpoint-minikube.sh && sudo /usr/local/bin/enable-checkpoint-minikube.sh"

echo "Minikube containerd configuration complete!"
echo "Now apply your DAKR snapshot setup DaemonSet to install CRIU and Netavark:"
echo "kubectl apply -f snapshot-setup-daemonset.yaml"

# Provide information about using the checkpoint API
echo ""
echo "To use the checkpoint API with the correct certificates, use:"
echo "curl -X POST --insecure --cert /var/lib/minikube/certs/apiserver-kubelet-client.crt --key /var/lib/minikube/certs/apiserver-kubelet-client.key https://NODE_IP:10250/checkpoint/NAMESPACE/POD/CONTAINER"
