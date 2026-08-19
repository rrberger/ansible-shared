#!/bin/bash
# entrypoints/bootstrap.sh

set -e

echo "Starting AWX bootstrap installer..."

# 1. Wait for K3s to generate the kubeconfig file
echo "Waiting for K3s to write kubeconfig to /shared/kubeconfig.yaml..."
while [ ! -f /shared/kubeconfig.yaml ]; do
  sleep 2
done

# Copy kubeconfig and change the server IP to point to the 'k3s' container hostname
cp /shared/kubeconfig.yaml /tmp/kubeconfig.yaml
sed -i 's/127.0.0.1/k3s/g' /tmp/kubeconfig.yaml
export KUBECONFIG=/tmp/kubeconfig.yaml
chmod 600 /tmp/kubeconfig.yaml

# 2. Wait for K3s API server to become responsive
echo "Waiting for Kubernetes API server to become ready..."
until kubectl get nodes &> /dev/null; do
  sleep 2
done
echo "Kubernetes API server is ready. Nodes:"
kubectl get nodes

# 3. Create Namespace
echo "Creating 'awx' namespace..."
kubectl create namespace awx --dry-run=client -o yaml | kubectl apply -f -

# 4. Install AWX Operator via Kustomize
echo "Setting up AWX Operator installation files..."
mkdir -p /tmp/awx-operator
cat <<EOF > /tmp/awx-operator/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/ansible/awx-operator/config/default?ref=2.19.1
namespace: awx
images:
  - name: quay.io/ansible/awx-operator
    newTag: 2.19.1
  - name: gcr.io/kubebuilder/kube-rbac-proxy
    newName: quay.io/brancz/kube-rbac-proxy
    newTag: v0.15.0
EOF

echo "Applying AWX Operator manifests..."
kubectl apply -k /tmp/awx-operator

# 5. Wait for the Operator Deployment to be ready
echo "Waiting for AWX Operator controller manager to be ready (timeout 5m)..."
kubectl -n awx rollout status deployment/awx-operator-controller-manager --timeout=300s

# 6. Apply AWX Custom Resource Definition
echo "Applying AWX Custom Resource deployment..."
kubectl apply -f /awx-instance.yaml -n awx

# 7. Wait for AWX Deployment to be created and rollout to complete
echo "Waiting for AWX deployment to be created..."
until kubectl -n awx get deployment awx-demo-web &> /dev/null; do
  sleep 10
done

echo "AWX deployment created. Waiting for web and task pods to roll out (timeout 10m)..."
kubectl -n awx rollout status deployment/awx-demo-web --timeout=600s

# Fetch AWX Admin credentials
echo "Fetching AWX Admin credentials..."
ADMIN_PASSWORD=$(kubectl -n awx get secret awx-demo-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")

# 8. Create EDA Namespace & Deploy EDA Operator + Instance
echo "Creating 'eda-server-operator-system' namespace..."
kubectl create namespace eda-server-operator-system --dry-run=client -o yaml | kubectl apply -f -

# Create EDA admin password secret if not already created
if ! kubectl -n eda-server-operator-system get secret eda-demo-admin-password &>/dev/null; then
  if [ -n "$ADMIN_PASSWORD" ]; then
    echo "Seeding EDA Admin credentials secret..."
    kubectl -n eda-server-operator-system create secret generic eda-demo-admin-password \
      --from-literal=password="$ADMIN_PASSWORD" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi
fi

echo "Applying EDA Operator manifests..."
kubectl apply -k "github.com/ansible/eda-server-operator/config/default?ref=1.0.2"


echo "Waiting for EDA Operator controller manager to be ready..."
kubectl -n eda-server-operator-system rollout status deployment/eda-server-operator-controller-manager --timeout=300s

if [ -f /eda-instance.yaml ]; then
  echo "Applying EDA Custom Resource deployment..."
  kubectl apply -f /eda-instance.yaml -n eda-server-operator-system

  echo "Waiting for EDA API deployment to be created..."
  until kubectl -n eda-server-operator-system get deployment eda-demo-api &> /dev/null; do
    sleep 5
  done

  echo "Waiting for EDA pods to roll out..."
  kubectl -n eda-server-operator-system rollout status deployment/eda-demo-api --timeout=600s
fi

# Fetch actual stored secrets for output display
AWX_PASS=$(kubectl -n awx get secret awx-demo-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(Preserved existing password)")
EDA_PASS=$(kubectl -n eda-server-operator-system get secret eda-demo-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(Preserved existing password)")

echo "========================================================================="
echo "                  AWX & EDA HOMELAB SETUP COMPLETE!                      "
echo "========================================================================="
echo " AWX Controller: http://localhost:8080"
echo "   Username:     admin"
echo "   Password:     ${AWX_PASS:-(Preserved existing password)}"
echo ""
echo " EDA Controller: http://localhost:8083"
echo "   Username:     admin"
echo "   Password:     ${EDA_PASS:-(Preserved existing password)}"
echo "========================================================================="
echo "Note: If accessing from a remote VM, replace 'localhost' with the VM's IP."
echo "Keep this process running, or press Ctrl+C (the containers will run in background)"
echo "========================================================================="

# Keep container alive so the logs can be inspected later
exec tail -f /dev/null
