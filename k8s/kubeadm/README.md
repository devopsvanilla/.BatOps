# Kubernetes 1.35 Setup - kubeadm Automation

> Complete quick-start guide for setting up a production-ready Kubernetes cluster on Ubuntu 24.04 LTS

**Latest Release**: v2.0 (March 6, 2026)  
**Status**: ✅ Production Ready

---

## 🎯 Quick Start

Get a fully functional Kubernetes cluster up and running in under 10 minutes:

```bash
# 1. Prepare the system
sudo bash ./install-requirements.sh

# 2. Initialize the control plane
sudo bash ./init-master.sh
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

### Add Worker Nodes
After master initialization, run on each worker:
```bash
kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
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

### Install Network Plugin (if needed)
```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### Check Cluster Status
```bash
kubectl cluster-info
kubectl get cs  # Component status
```

### Reset a Failed Installation
```bash
sudo kubeadm reset -f
sudo bash ./install-requirements.sh  # Then try again
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
