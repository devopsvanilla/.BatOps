# Kubernetes kubeadm Upgrade Orchestrator

Guia para uso do script `orchestrate-kubeadm-upgrade.sh`, que:

- descobre automaticamente os nós do cluster;
- define a ordem segura de upgrade;
- gera um plano em Markdown com comandos por nó;
- opcionalmente gera comandos remotos via SSH por nó;
- opcionalmente executa o upgrade **apenas no nó local**.

---

## Arquivos envolvidos

- `orchestrate-kubeadm-upgrade.sh` → planejamento/orquestração
- `upgrade-kubeadm.sh` → execução do upgrade por nó (control plane/worker)

---

## Pré-requisitos

- Cluster acessível via `kubectl` a partir do control plane
- `upgrade-kubeadm.sh` disponível no mesmo diretório
- Repositório de pacotes Kubernetes (`pkgs.k8s.io`) já apontando para a versão alvo
- Backup/snapshot (especialmente etcd)
- Janela de manutenção aprovada

---

## Modo 1: Gerar plano de upgrade (recomendado)

```bash
bash ./orchestrate-kubeadm-upgrade.sh --target v1.35.2
```

Resultado:

- imprime inventário do cluster (control planes e workers)
- define o primeiro control plane
- gera um arquivo como:
  - `UPGRADE-PLAN-v1.35.2-YYYYMMDD-HHMMSS.md`

---

## Modo 2: Gerar plano com nome customizado

```bash
bash ./orchestrate-kubeadm-upgrade.sh --target v1.35.2 --output ./upgrade-plan-v1.35.2.md
```

---

## Modo 3: Gerar plano com comandos SSH por nó

Use quando você quer um runbook pronto para copiar/colar remotamente em cada node.

```bash
bash ./orchestrate-kubeadm-upgrade.sh \
  --target v1.35.2 \
  --ssh-user ubuntu \
  --ssh-key ~/.ssh/id_ed25519
```

Opcionalmente, você pode ajustar a porta SSH:

```bash
bash ./orchestrate-kubeadm-upgrade.sh --target v1.35.2 --ssh-user ubuntu --ssh-key ~/.ssh/id_ed25519 --ssh-port 2222
```

---

## Modo 4: Executar upgrade local via orquestrador

> Este modo **não** executa remotamente em outros nós.
> Ele apenas detecta o papel do nó atual e chama `upgrade-kubeadm.sh` localmente.

### Em um control plane

```bash
sudo bash ./orchestrate-kubeadm-upgrade.sh --target v1.35.2 --execute-local
```

### Em um worker com drain automático

```bash
sudo bash ./orchestrate-kubeadm-upgrade.sh --target v1.35.2 --execute-local --manage-drain-workers
```

---

## Estratégia operacional recomendada

1. Gere o plano no primeiro control plane.
2. Execute no primeiro control plane (`control-plane-first`).
3. Execute nos control planes adicionais (`control-plane`).
4. Execute nos workers, um por vez (`worker` + drain/uncordon).
5. Valide saúde do cluster após cada nó.

---

## Segurança aplicada

- ordem correta de upgrade (`control-plane-first` → `control-plane` → `worker`)
- execução local controlada (sem automação remota implícita)
- prompts de confirmação (a menos que `--yes`)
- separação de responsabilidades entre planejamento e execução

---

## Flags disponíveis

### `orchestrate-kubeadm-upgrade.sh`

- `--target <vX.Y.Z>` (obrigatório)
- `--output <arquivo.md>`
- `--ssh-user <usuario>`
- `--ssh-key <caminho>`
- `--ssh-port <porta>`
- `--execute-local`
- `--manage-drain-workers`
- `--yes`
- `-h`, `--help`

### `upgrade-kubeadm.sh`

- `--role <control-plane-first|control-plane|worker>`
- `--target <vX.Y.Z>`
- `--manage-drain` (workers)
- `--yes`

---

## Validações pós-upgrade

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Checklist final:

- todos os nós em `Ready`
- versões de `kubelet` conforme alvo
- componentes críticos em `kube-system` saudáveis
- workloads de negócio sem degradação

---

## Observações importantes

- Faça upgrade **de um minor por vez** (ex.: `1.34 -> 1.35`).
- Não faça upgrade em paralelo em múltiplos nós.
- Sempre valide após cada nó antes de seguir para o próximo.
- `--ssh-key` exige `--ssh-user`.
