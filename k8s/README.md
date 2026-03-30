# ☸️ Kubernetes — Soluções BatOps

Soluções para instalação de clusters e deploy de aplicações em Kubernetes.

---

## 📋 Soluções Disponíveis

| Solução | Descrição | Documentação |
|---|---|---|
| `kubeadm/` | Scripts para automação de instalação de cluster via kubeadm | [docs](kubeadm/README.md) |
| `nginx-nodeport-deployment/` | Deploy de exemplo de Nginx exposto via NodePort | [docs](nginx-nodeport-deployment/README.md) |

---

## 🚀 Como Utilizar

### 1. Instalação de Cluster

Consulte o diretório [kubeadm/](kubeadm/) para scripts de preparação de runtime, inicialização de control-plane e ingresso de workers.

### 2. Deploy de Aplicação (Nginx)

```bash
cd nginx-nodeport-deployment/
./deploy.sh
```

---

## 🛠️ Detalhes e Requisitos

- `kubectl` instalado e configurado
- Cluster Kubernetes ativo (para deploys)
- Permissões de root no host (para instalação via kubeadm)

---

## 📚 Referências

- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
