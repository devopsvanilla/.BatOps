# Kubernetes 1.35 Setup - kubeadm Automation

> Complete quick-start guide for setting up a production-ready Kubernetes cluster on Ubuntu 24.04 LTS

**Latest Release**: v2.0 (March 6, 2026)  
**Status**: ✅ Production Ready

---

## 🎯 Quick Start

Get a fully functional Kubernetes cluster up and running in under 15 minutes:

```bash
# 1. Prepare the system
sudo bash ./install-requirements.sh

# 2. Initialize the control plane
sudo bash ./init-master.sh

# 3. Configure kubectl for your user
bash ./setup-kubectl.sh

# 4. Install network plugin (Flannel)
bash ./install-flannel.sh
```

That's it! Your cluster is ready to deploy pods.

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

### `install-flannel.sh` - Network Plugin Installation
- ✅ Downloads and applies latest Flannel manifest
- ✅ Detects and handles existing installations
- ✅ Monitors pod deployment progress (with timeout)
- ✅ Validates all nodes become Ready
- ✅ Color-coded status messages
- ✅ Comprehensive error reporting

---

## 🖥️ System Requirements

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

### Install Network Plugin
```bash
# Automated installation with validation
bash ./install-flannel.sh

# Or manual installation
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

**Node showing "NotReady"?**
```bash
# Check network plugin
kubectl get pods -n kube-system | grep flannel
```

**Can't connect to cluster?**
```bash
# Verify kubeconfig
echo $KUBECONFIG
kubectl config current-context
```

**Port conflicts?**
```bash
# Check Kubernetes ports
sudo netstat -tlnp | grep -E ':(6443|2379|10250)'
```

See [RELEASE.md](RELEASE.md#-troubleshooting) for more solutions.

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
