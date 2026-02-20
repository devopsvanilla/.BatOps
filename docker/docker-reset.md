# docker-reset.sh

Documentação do script `docker-reset.sh`, localizado em `docker/`, para limpeza e reset de ambiente Docker.

---

## Visão geral

O script oferece duas operações principais:

1. **Limpeza de recursos não utilizados**
   - Preserva recursos em uso por containers ativos.
2. **Reset total do Docker**
   - Remove containers, imagens, volumes, redes customizadas, cache e dados persistentes.
   - Pode desabilitar serviços `systemd` que iniciam `docker compose` automaticamente (modo aplicável no reset total).

---

## Pré-requisitos

- Docker instalado e funcional.
- Sistema Linux com `systemd` (para etapas de serviço usadas no reset total).
- Permissão de `sudo` para operações destrutivas e gerenciamento de serviço.

> ⚠️ **Atenção:** o reset total é destrutivo e pode apagar completamente o estado local do Docker.

---

## Uso

```bash
./docker-reset.sh [opções]
```

### Opções

- `-h`, `--help`  
  Exibe ajuda e sai.

- `--option`, `-o N`  
  Define a opção sem prompt interativo:
  - `1` = limpeza de não utilizados
  - `2` = reset total

- `--yes`, `-y`  
  Confirma automaticamente prompts destrutivos.

- `--nuclear`  
  No reset total, exibe prévia de serviços `systemd` com `docker compose`/`docker-compose` e adiciona confirmação extra.

- `--dry-run`  
  Simula ações sem executar remoções.

---

## Modos de execução

### 1) Interativo

Sem `--option`, o script pergunta:

- Opção `1` ou `2`.
- Confirmações de segurança (na opção 2).

### 2) Não interativo

Com `--option`, você evita prompt de escolha.

Exemplo:

```bash
./docker-reset.sh --option 2 --yes
```

---

## O que cada opção faz

### Opção 1 — Limpeza de não utilizados

- Remove containers parados (`exited`, `created`, `dead`).
- Limpa cache Buildx não utilizado.
- Executa `docker system prune --all --volumes --force`.
- Mantém recursos associados a containers em execução.

### Opção 2 — Reset total

Fluxo resumido:

1. Desabilita política de restart dos containers (`--restart=no`).
2. Detecta e desabilita unidades `systemd` que executam `docker compose`/`docker-compose`.
3. Remove stacks/serviços de Swarm (se ativo).
4. Para e remove containers em múltiplas passadas.
5. Remove imagens, volumes e redes customizadas.
6. Limpa cache Buildx e faz `system prune`.
7. Para `docker.service`, `docker.socket` e `containerd.service`.
8. Remove e recria `/var/lib/docker` e `/var/lib/containerd`.
9. Limpa logs/socket/pid.
10. Reinicia serviços e faz verificação final.

---

## `--dry-run` (simulação)

Quando usado:

- **Não remove nada.**
- Mostra prévia do que seria afetado.

### Simulação da opção 1

- Quantidade de containers parados que seriam removidos.
- Indica que Buildx prune e system prune seriam executados.

### Simulação da opção 2

- Quantidade de:
  - containers em execução (que seriam parados)
  - containers totais (que seriam removidos)
  - imagens
  - volumes
  - redes customizadas
- Lista serviços `systemd` com compose que seriam desabilitados (quando detectados).
- Informa etapas destrutivas que seriam executadas no reset.

---

## Exemplos práticos

### Limpeza simples (interativo)

```bash
./docker-reset.sh
```

### Limpeza não interativa (opção 1)

```bash
./docker-reset.sh --option 1
```

### Reset total com confirmação manual

```bash
./docker-reset.sh --option 2
```

### Reset total com confirmação automática

```bash
./docker-reset.sh --option 2 --yes
```

### Reset total com prévia de serviços compose e confirmação extra

```bash
./docker-reset.sh --option 2 --nuclear
```

### Reset total com `--nuclear` e sem prompts

```bash
./docker-reset.sh --option 2 --nuclear --yes
```

### Simular reset total sem alterar nada

```bash
./docker-reset.sh --option 2 --nuclear --dry-run
```

---

## Segurança e boas práticas

- Use `--dry-run` antes de operações destrutivas em ambientes sensíveis.
- Em hosts compartilhados, revise impacto em serviços dependentes do Docker.
- Faça backup de dados importantes antes de reset total.
- Em automações CI/CD, combine `--option 2 --yes` somente quando o impacto estiver totalmente previsto.

---

## Solução de problemas

- **Containers reaparecem após reset**  
  Verifique automações externas (`systemd`, cron, orchestrators) que possam recriar workloads.

- **Falha por permissão**  
  Confirme acesso `sudo` e disponibilidade de `systemctl`.

- **Docker não inicializa após reset**  
  Consulte logs de serviço (`journalctl`) e status do daemon (`systemctl status docker`).

---

## Arquivos relacionados

- Script: `docker/docker-reset.sh`
- Esta documentação: `docker/docker-reset.md`
