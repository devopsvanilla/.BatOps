# get-credential.sh — Usage and security guide

This document explains how to use the `get-credential.sh` script to retrieve:

- Kubernetes API URL
- API token

---

## Prerequisites

- `kubectl` installed and working
- Current `kubectl` context pointing to the target cluster
- Permissions to create ServiceAccount/ClusterRoleBinding (when needed)

---

## Basic usage

Run with default settings:

```bash
bash ./get-credential.sh
```

Expected output:

- `API URL: https://...`
- `API Token: eyJ...`

---

## Available options

### `--duration <time>`
Sets the **bound token** duration (recommended).

Examples:

```bash
bash ./get-credential.sh --duration 24h
bash ./get-credential.sh --duration 720h
bash ./get-credential.sh --duration 30m
```

### `--namespace <namespace>`
Defines the ServiceAccount namespace used to generate the token.

```bash
bash ./get-credential.sh --namespace kube-system
```

### `--serviceaccount <name>`
Defines the ServiceAccount name.

```bash
bash ./get-credential.sh --serviceaccount api-access
```

### `--insecure-long-lived`
Attempts to generate a legacy static token (without explicit expiration).

> ⚠️ **Not recommended for production**.

```bash
bash ./get-credential.sh --insecure-long-lived
```

### `--help`
Shows script help.

```bash
bash ./get-credential.sh --help
```

---

## Security recommendations

1. **Always prefer expiring tokens** (`--duration`) over static tokens.
2. **Do not use `cluster-admin` in production** unless strictly required.
3. **Never commit tokens to Git** (README, scripts, `.env`, CI logs, etc.).
4. **Store tokens in a secrets vault** (Vault, Secret Manager, etc.).
5. **Apply least privilege** (minimum RBAC required).
6. **Rotate tokens regularly**.
7. **Revoke immediately** if compromise is suspected.
8. **Avoid sharing tokens over chat/email** without protection.

---

## Operational best practices

- Generate tokens per environment (dev/stage/prod) with separate ServiceAccounts.
- Document owner and purpose for each credential.
- Use short-lived tokens for pipelines and temporary automations.
- Monitor credential usage in cluster audit logs.

---

## Quick troubleshooting

### Error: `kubectl not found`
Install/configure `kubectl` on the host.

### Error: `Unable to connect to cluster`
Check context and kubeconfig:

```bash
kubectl config current-context
kubectl cluster-info
```

### Error while generating legacy static token
Some modern clusters block this type for security reasons.
Use a bound token with `--duration`.

---

## Recommended examples

Production (safer):

```bash
bash ./get-credential.sh --duration 24h
```

Long-running automation (still expiring):

```bash
bash ./get-credential.sh --duration 720h
```

Lab only (only if needed):

```bash
bash ./get-credential.sh --insecure-long-lived
```
