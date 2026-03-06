# Kubernetes 1.35 Setup via kubeadm - Release v2.0

> **Release Date**: March 6, 2026  
> **Compatibility**: Ubuntu 24.04 LTS | Kubernetes 1.35 | containerd

---

## 🎯 Overview

Complete automation suite for setting up a production-ready Kubernetes cluster on Ubuntu 24.04 LTS using kubeadm. This release introduces enhanced container runtime configuration and a new interactive master node initialization script.

---

## ✨ What's New in This Release

### 1. **Enhanced Container Runtime Configuration**
Optimized containerd setup with full CRI compatibility:
- Automatic `SystemdCgroup` driver configuration
- Correct sandbox image pinning (`pause:3.10.1`)
- Zero runtime compatibility warnings
- Full support for Kubernetes 1.35 CRI specifications

### 2. **New Master Initialization Script** (`init-master.sh`)
Interactive automation for control plane setup:
- Pre-flight checks and reset capability
- Automatic image pre-loading via `kubeadm config images pull`
- One-command cluster initialization
- Auto-configuration of kubectl with proper permissions
- Clear step-by-step feedback with estimated timings

### 3. **Improved System Preparation** (`install-requirements.sh`)
Enhanced pre-installation workflow:
- Smart detection of existing Kubernetes components
- Graceful handling of reinstallation scenarios
- Better network configuration for pod communication
- Comprehensive system state verification

### 4. **Best Practices Integration**
- Image pre-loading (prevents timeout issues)
- Flannel CNI plugin pre-configuration (10.244.0.0/16)
- Optimized sysctl and kernel module settings
- Proper service lifecycle management

---

## 📦 Components Included

| Component | Purpose |
|-----------|---------|
| `install-requirements.sh` | System preparation and dependency installation |
| `init-master.sh` | Control plane initialization and configuration |
| `kube-flannel.yml` | Network plugin (applied via kubectl) |

---

## 🚀 Quick Start

### Method 1: Automated Setup (Recommended)
```bash
# Step 1: Prepare the system
sudo bash ./install-requirements.sh

# Step 2: Initialize the control plane
sudo bash ./init-master.sh
```

### Method 2: Step-by-Step Manual Setup
```bash
# Step 1: System preparation
sudo bash ./install-requirements.sh

# Step 2: Pre-load container images
sudo kubeadm config images pull

# Step 3: Initialize control plane
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Step 4: Configure kubectl access
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Step 5: Deploy network plugin
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

---

## ✅ Verification

After setup completes, verify your cluster:

```bash
# Check node status (should show "Ready")
kubectl get nodes

# Monitor system pods (wait for "Running" state)
kubectl get pods -n kube-system -w

# Verify container runtime
systemctl status containerd
```

**Expected output**:
```
NAME                STATUS   ROLES           AGE   VERSION
k8s-master-01       Ready    control-plane   2m    v1.35.x
```

---

## 🔧 Features

### Container Runtime Optimization
- ✅ SystemdCgroup driver enabled
- ✅ Sandbox image versioning (3.10.1)
- ✅ Full CRI method support
- ✅ Zero configuration warnings

### Network Configuration
- ✅ Pro-configured for Flannel CNI
- ✅ Pod network CIDR: 10.244.0.0/16
- ✅ IP forwarding enabled
- ✅ Bridge networking ready

### Cluster Management
- ✅ SWAP disabled (Kubernetes requirement)
- ✅ Kernel modules auto-loaded
- ✅ sysctl parameters optimized
- ✅ kubelet auto-start enabled

---

## 📝 Configuration Options

### Custom Pod Network CIDR
To use a different pod network range:

```bash
# Edit the scripts or pass as environment variable
CIDR=192.168.0.0/16 sudo bash ./init-master.sh

# Or modify the command directly
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

### Adding Worker Nodes
After control plane initialization, you'll receive a `kubeadm join` command. Run it on each worker node:

```bash
# On each worker node (as root)
kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

---

## 🐛 Troubleshooting

### "Node stuck in NotReady state"
```bash
# Ensure network plugin is running
kubectl get pods -n kube-system | grep flannel

# If not running, apply the manifest
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### "Sandbox image warning"
This release includes automatic configuration to eliminate sandbox image warnings. If still seen, verify:
```bash
grep "sandbox_image" /etc/containerd/config.toml
# Should output: sandbox_image = "registry.k8s.io/pause:3.10.1"
```

### "Container runtime version warning"
This is resolved by the enhanced containerd configuration:
```bash
grep "SystemdCgroup" /etc/containerd/config.toml
# Should output: SystemdCgroup = true
```

---

## 📋 System Requirements

- **OS**: Ubuntu 24.04 LTS
- **CPU**: 2+ cores (4+ recommended for production)
- **RAM**: 2GB minimum (4GB+ recommended)
- **Disk**: 20GB+ free space
- **Network**: Internet connectivity for package/image downloads
- **Privileges**: Root or sudo access

---

## 🔗 References

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [Container Runtimes - containerd](https://kubernetes.io/docs/setup/production-environment/container-runtimes/containerd/)
- [Flannel Networking](https://github.com/flannel-io/flannel)
- [CRI Specifications](https://kubernetes.io/docs/concepts/architecture/cri/)

---

## 📅 Version History

### v2.0 - March 6, 2026
- ✨ New `init-master.sh` script with full automation
- 🐛 Fixed container runtime compatibility warnings
- 🔧 Enhanced containerd configuration
- 📖 Improved documentation and best practices
- ⚡ Performance optimizations

### v1.0 - Initial Release
- Basic system preparation script
- Initial Kubernetes 1.35 support
