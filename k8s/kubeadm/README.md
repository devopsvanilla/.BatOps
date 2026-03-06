# Kubernetes 1.35 Setup - kubeadm Automation

> Complete quick-start guide for setting up a production-ready Kubernetes cluster on Ubuntu 24.04 LTS

**Latest Release**: v2.0 (March 6, 2026)  
**Status**: ✅ Production Ready

---

## 🎯 Quick Start

Get a fully functional Kubernetes cluster up and running in under 15 minutes:

```bash
# 1) REQUIRED - Prepare the system
sudo bash ./install-requirements.sh

# 2) REQUIRED - Initialize the control plane
sudo bash ./init-master.sh

# 3) REQUIRED (for non-root kubectl usage) - Configure kubectl for your user
bash ./setup-kubectl.sh

# 4) REQUIRED - Install network plugin (Flannel + CNI checks)
bash ./install-flannel.sh
```

After this sequence, confirm the node is `Ready`:

```bash
kubectl get nodes
```

Then your cluster is ready to deploy pods.

---

## ✅ Correct Execution Order (Required vs Optional)

Run scripts in this exact order:

1. **`install-requirements.sh`** → **Required**
2. **`init-master.sh`** → **Required**
3. **`setup-kubectl.sh`** → **Required** for day-to-day use as non-root user
4. **`install-flannel.sh`** → **Required** (without CNI/plugin, node stays `NotReady`)
5. **`add-worker.sh`** → Optional (only when adding worker nodes)

> If you skip `install-flannel.sh`, kubelet will report `cni plugin not initialized` and node status will remain `NotReady`.

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[RELEASE.md](RELEASE.md)** | What's new, features, and detailed setup instructions |
| **[install-requirements.md](install-requirements.md)** | System preparation details and troubleshooting |

---

## 📂 Files Included

```
kubeadm/
├── README.md                    (this file)
├── RELEASE.md                   (release notes & features)
├── install-requirements.sh      (system preparation)
├── init-master.sh              (cluster initialization)
├── setup-kubectl.sh            (user kubectl configuration)
├── install-flannel.sh          (CNI network plugin installation)
├── add-worker.sh               (secure worker node addition)
└── install-requirements.md     (technical documentation)
```

---

## ⚡ What Happens

### `install-requirements.sh` - System Setup
- ✅ Disables SWAP
- ✅ Loads kernel modules (overlay, br_netfilter)
- ✅ Configures sysctl parameters
- ✅ Installs containerd + Kubernetes tools
- ✅ Optimizes container runtime
- ✅ Smart handling of existing installations

### `init-master.sh` - Cluster Bootstrap
- ✅ Pre-loads container images
- ✅ Initializes Kubernetes control plane
- ✅ Configures kubectl
- ✅ Provides worker node joining instructions

### `add-worker.sh` - Secure Worker Addition
- ✅ Generates fresh token on each run (24h validity)
- ✅ Displays join command without saving to disk
- ✅ No token file leaks or security risks
- ✅ Optional clipboard copy (xclip support)

### `setup-kubectl.sh` - User kubectl Configuration
- ✅ Configures kubeconfig for current user
- ✅ Sets correct file permissions (600)
- ✅ Tests cluster connectivity
- ✅ Optionally adds to shell profile (.bashrc, .zshrc, etc)
- ✅ Security warnings and best practices

### `install-flannel.sh` - Network Plugin Installation + CNI Setup
- ✅ Checks and installs `kubernetes-cni` package (CNI prerequisites)
- ✅ Creates required directories (`/etc/cni/net.d`, `/opt/cni/bin`)
- ✅ Guarantees essential CNI plugins (`loopback`, `bridge`, `host-local`, `portmap`)
- ✅ Downloads and applies latest Flannel manifest
- ✅ Detects and handles existing installations
- ✅ Monitors pod deployment progress (with timeout)
- ✅ Validates all nodes become Ready
- ✅ Restarts container runtime to apply CNI configuration
- ✅ Validates CoreDNS rollout and reports actionable diagnostics
- ✅ Color-coded status messages
- ✅ Comprehensive error reporting

---

## � Post-Installation Verification

After running all 4 required scripts, verify your cluster:

```bash
# Check node status (should show "Ready")
kubectl get nodes -o wide

# Check all system pods
kubectl get pods -A -o wide
```

**Expected Status:**
- Node: `Ready`
- Flannel DaemonSet: `1/1 Running`
- CoreDNS: `Running` (or briefly `ContainerCreating`)
- etcd, kube-apiserver, kube-controller-manager, kube-scheduler: `1/1 Running`

### Single-Node Cluster Note

If CoreDNS pods remain in `ContainerCreating` state briefly after setup, this is normal:
- The control-plane taint is automatically removed after CNI initialization
- CoreDNS will transition to `Running` within 30-60 seconds
- The Flannel network plugin must be fully initialized before CoreDNS can start

You can monitor this with:
```bash
kubectl get pods -n kube-system -w
```

---

- **OS**: Ubuntu 24.04 LTS
- **CPU**: 2+ cores (4+ recommended)
- **RAM**: 2GB+ (4GB+ recommended)
- **Disk**: 20GB+ free space
- **Network**: Internet access
- **Privileges**: root or sudo

---

## 🔧 Advanced Usage

### Custom Pod Network CIDR
```bash
# Change the network range (default: 10.244.0.0/16)
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

### Manual Step-by-Step Setup
See [RELEASE.md - Method 2](RELEASE.md#method-2-step-by-step-manual-setup)

### Configure kubectl for User
After master initialization, configure kubectl access:

```bash
# Setup kubeconfig in user profile
bash ./setup-kubectl.sh

# Optionally add to shell profile (.bashrc, .zshrc, etc)
# Script will ask if you want to do this
```

### Add Worker Nodes
The secure way to add worker nodes to your cluster:

```bash
# On MASTER node, generate a new token and join command
sudo bash ./add-worker.sh

# Copy the displayed command and run on WORKER node
# The script generates a fresh token each time (24h validity)
```

---

## ✅ Verify Installation

```bash
# Should show master node as Ready
kubectl get nodes

# Should show all system pods as Running
kubectl get pods -n kube-system

# Test with a simple deployment
kubectl create deployment nginx --image=nginx
kubectl get deployments
```

---

## 📖 Common Tasks

### Install Network Plugin (**Required**)
```bash
# Automated installation with validation + CNI prerequisites
bash ./install-flannel.sh

# Or manual installation (advanced)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### Check Cluster Status
```bash
kubectl cluster-info
kubectl get cs  # Component status
```

### Add Worker Nodes
```bash
# Securely generate join command (on MASTER)
sudo bash ./add-worker.sh

# Run the output command on each WORKER node
```

### Regenerate Worker Token
```bash
# If the worker token expires (24h), run again on MASTER
sudo bash ./add-worker.sh
```

### Reset a Failed Installation
```bash
sudo kubeadm reset -f
sudo bash ./install-requirements.sh  # Then try again
```

### Reconfigure kubectl (User)
If kubeconfig gets corrupted or needs reset:
```bash
rm -rf ~/.kube
bash ./setup-kubectl.sh  # Reconfigure
```

---

## 🐛 Troubleshooting

### "Node stuck in NotReady state" / "cni plugin not initialized"

**Symptom:**
```bash
kubectl get nodes
# Output: STATUS = NotReady

kubectl describe node <node>
# Message: "cni plugin not initialized"
```

**Root cause:** Flannel or CNI plugins were not installed

**Solution:**
```bash
# Ensure kubernetes-cni package is installed
sudo apt-get install -y kubernetes-cni

# Install Flannel (includes CNI setup)
bash ./install-flannel.sh

# Verify
kubectl get nodes  # should show Ready
kubectl get pods -n kube-flannel  # should show pods Running
```

### CoreDNS pods in ContainerCreating

**Symptom:**
```bash
kubectl get pods -n kube-system | grep coredns
# STATUS = ContainerCreating (for 30-60 seconds)
```

**Cause:** Normal behavior while Flannel network is initializing (single-node clusters)

**Action:** Wait 1-2 minutes. If still `ContainerCreating`:
```bash
kubectl describe pod -n kube-system <coredns-pod-name>
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

### Network plugin check
```bash
# Verify Flannel is deployed
kubectl get ds -n kube-flannel
kubectl get pods -n kube-flannel -o wide

# Check Flannel logs
kubectl logs -n kube-flannel -l app=flannel --tail=100
```

---

## 🔗 Resources

- [RELEASE.md](RELEASE.md) - Full release notes and features
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/containerd/)

---

## 📝 Version Info

| Version | Date | Changes |
|---------|------|---------|
| **v2.0** | Mar 6, 2026 | New `init-master.sh`, enhanced runtime config, release docs |
| v1.0 | Feb 2026 | Initial release |

---

## ⚠️ Important Notes

- ⚠️ SWAP must be disabled - the script handles this automatically
- ⚠️ Root or sudo access required for system preparation
- ⚠️ Pre-load images if internet is slow: `sudo kubeadm config images pull`
- ⚠️ Backup kubeadm join output - you'll need it for worker nodes

---

## 🆘 Support

For issues or improvements, refer to:
- [RELEASE.md - Troubleshooting Section](RELEASE.md#-troubleshooting)
- [install-requirements.md](install-requirements.md)

---

**Ready to deploy?** Start with:
```bash
sudo bash ./install-requirements.sh && sudo bash ./init-master.sh
```
