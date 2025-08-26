# checkNetworkConnectivity.md

# Procedimento de Verificação de Conectividade de Rede para Kubernetes

Este procedimento orienta como verificar a conectividade bidirecional entre a rede onde está instalado o cluster Kubernetes e a rede que acessará as aplicações.

## Informações de Exemplo Utilizadas

- **Rede do Cluster Kubernetes**: 172.16.0.0/24 (Control Plane: 172.16.0.135)
- **Rede de Acesso às Aplicações**: 172.16.10.0/24 (Cliente Windows: 172.16.10.120)
- **Sistema Cliente**: Windows 11 com PowerShell

## 1. Verificação da Conectividade do Cliente Windows para o Kubernetes

### 1.1 Verificar se existe rota configurada

```
# Verificar rota específica para o IP do cluster
Find-NetRoute -RemoteIPAddress 172.16.0.135

# Verificar todas as rotas para a rede do cluster
Get-NetRoute | Where-Object {$_.DestinationPrefix -like "172.16.0.*"}
```

**Resultado esperado:**
- Se houver conectividade: retorna DestinationPrefix, NextHop e InterfaceAlias
- Se não houver: erro "No route found" ou sem retorno

### 1.2 Testar conectividade básica

```
# Teste de ping simples
Test-NetConnection -ComputerName 172.16.0.135 -InformationLevel Quiet

# Teste detalhado com traceroute
Test-NetConnection -ComputerName 172.16.0.135 -TraceRoute -InformationLevel Detailed
```

### 1.3 Testar conectividade com serviços Kubernetes

```
# Testar API Server do Kubernetes (porta 6443)
Test-NetConnection -ComputerName 172.16.0.135 -Port 6443

# Testar outras portas comuns do Kubernetes
Test-NetConnection -ComputerName 172.16.0.135 -Port 80   # HTTP
Test-NetConnection -ComputerName 172.16.0.135 -Port 443  # HTTPS
Test-NetConnection -ComputerName 172.16.0.135 -Port 22   # SSH
```

### 1.4 Script completo de diagnóstico do Windows

```
Write-Host "=== Teste de Conectividade Windows -> Kubernetes ===" -ForegroundColor Yellow

$KubernetesIP = "172.16.0.135"

# Verificar rota
Write-Host "`n1. Verificando rota para $KubernetesIP :" -ForegroundColor Green
try {
    $route = Find-NetRoute -RemoteIPAddress $KubernetesIP
    Write-Host "Rota encontrada: $($route.DestinationPrefix) via $($route.NextHop)" -ForegroundColor Green
} catch {
    Write-Host "ERRO: Nenhuma rota encontrada para $KubernetesIP" -ForegroundColor Red
}

# Teste de ping
Write-Host "`n2. Teste de ping:" -ForegroundColor Green
$pingResult = Test-NetConnection -ComputerName $KubernetesIP -InformationLevel Quiet
if ($pingResult) {
    Write-Host "✓ Ping bem-sucedido" -ForegroundColor Green
} else {
    Write-Host "✗ Ping falhou" -ForegroundColor Red
}

# Teste de portas
Write-Host "`n3. Teste de conectividade de portas:" -ForegroundColor Green
$ports = @(22, 80, 443, 6443)
foreach ($port in $ports) {
    $portTest = Test-NetConnection -ComputerName $KubernetesIP -Port $port -InformationLevel Quiet
    if ($portTest.TcpTestSucceeded) {
        Write-Host "✓ Porta $port : ABERTA" -ForegroundColor Green
    } else {
        Write-Host "✗ Porta $port : FECHADA/FILTRADA" -ForegroundColor Red
    }
}

# Traceroute
Write-Host "`n4. Traceroute para identificar o caminho:" -ForegroundColor Green
Test-NetConnection -ComputerName $KubernetesIP -TraceRoute | Select-Object -ExpandProperty TraceRoute
```

## 2. Verificação da Conectividade do Kubernetes para o Cliente Windows

### 2.1 Acessar o Control Plane do Kubernetes

```
# SSH para o Control Plane
ssh usuario@172.16.0.135

# Ou kubectl exec se necessário
kubectl exec -it <pod-name> -- /bin/bash
```

### 2.2 Verificar se existe rota para a rede do cliente

```
# Verificar rota específica para o IP do cliente Windows
ip route get 172.16.10.120

# Verificar todas as rotas para a rede do cliente
ip route show | grep 172.16.10

# Listar todas as rotas configuradas
ip route show
```

**Resultado esperado:**
- Se houver conectividade: `172.16.10.120 via [gateway] dev [interface]`
- Se não houver: `RTNETLINK answers: Network is unreachable`

### 2.3 Testar conectividade básica do Kubernetes

```
# Teste de ping
ping -c 4 172.16.10.120

# Teste de traceroute
traceroute 172.16.10.120

# Teste de conectividade TCP (se disponível)
nc -zv 172.16.10.120 22
```

### 2.4 Verificar configuração de rede do Kubernetes

```
# Verificar interfaces de rede disponíveis
ip addr show

# Verificar gateway padrão
ip route show default

# Verificar configuração do CNI
kubectl get pods -n kube-system | grep -E "(calico|flannel|weave)"

# Verificar logs de rede (exemplo com Calico)
kubectl logs -n kube-system <calico-pod-name>
```

### 2.5 Script completo de diagnóstico do Kubernetes

```
#!/bin/bash
echo "=== Teste de Conectividade Kubernetes -> Windows ==="

WINDOWS_IP="172.16.10.120"

echo -e "\n1. Verificando rota para $WINDOWS_IP:"
ip route get $WINDOWS_IP 2>/dev/null || echo "ERRO: Nenhuma rota encontrada"

echo -e "\n2. Verificando todas as rotas para 172.16.10.x:"
ip route show | grep 172.16.10 || echo "Nenhuma rota para rede 172.16.10.x"

echo -e "\n3. Teste de ping:"
ping -c 3 -W 3 $WINDOWS_IP && echo "✓ Ping bem-sucedido" || echo "✗ Ping falhou"

echo -e "\n4. Teste de traceroute:"
traceroute -m 5 $WINDOWS_IP 2>/dev/null || echo "Traceroute falhou"

echo -e "\n5. Verificando interfaces de rede:"
ip addr show | grep -E "^[0-9]+:|inet "

echo -e "\n6. Verificando gateway padrão:"
ip route show default
```

## 3. Interpretação dos Resultados

### 3.1 Cenários Possíveis

| Teste Windows -> K8s | Teste K8s -> Windows | Diagnóstico | Solução |
|---------------------|---------------------|-------------|---------|
| ✓ Sucesso | ✓ Sucesso | **Conectividade OK** | Nenhuma ação necessária |
| ✓ Sucesso | ✗ Falha | **Roteamento assimétrico** | Adicionar rota no K8s para 172.16.10.0/24 |
| ✗ Falha | ✗ Falha | **Sem conectividade** | Verificar infraestrutura de rede |
| ✗ Falha | ✓ Sucesso | **Rota ausente no Windows** | Adicionar rota no Windows |

### 3.2 Problemas Comuns e Soluções

**Problema: "Network is unreachable" no Kubernetes**
```
# Solução: Adicionar rota manual
sudo ip route add 172.16.10.0/24 via [GATEWAY] dev [INTERFACE]

# Ou adicionar interface de rede adicional
sudo ip addr add 172.16.10.100/24 dev eth1
sudo ip link set eth1 up
```

**Problema: Timeout em Test-NetConnection no Windows**
```
# Verificar firewall
Get-NetFirewallRule | Where-Object {$_.Enabled -eq "True" -and $_.Direction -eq "Outbound"}

# Testar com timeout menor
Test-NetConnection -ComputerName 172.16.0.135 -Port 6443 -InformationLevel Detailed
```

## 4. Validação Final

### 4.1 Teste de aplicação real

**No Kubernetes - criar um pod de teste:**
```
kubectl run test-pod --image=nginx --port=80
kubectl expose pod test-pod --type=NodePort --port=80
kubectl get svc test-pod
```

**No Windows - testar acesso ao serviço:**
```
$NodePort = 30123  # Substitua pela porta retornada
Test-NetConnection -ComputerName 172.16.0.135 -Port $NodePort
```

### 4.2 Teste bidirecional completo

```
# No Kubernetes - testar conexão de volta
kubectl run test-connectivity --image=busybox --rm -it --restart=Never -- wget -qO- http://172.16.10.120
```

## 5. Próximos Passos

Se os testes identificarem problemas de conectividade:

1. **Roteamento assimétrico detectado**: Implementar placa de rede adicional no cluster
2. **Sem conectividade**: Consultar administrador de rede sobre roteamento entre VLANs
3. **Firewall bloqueando**: Configurar regras de firewall adequadas
4. **DNS não resolvendo**: Configurar resolução DNS ou usar IPs diretos

---

**Importante**: Este procedimento assume que ambas as redes estão na mesma infraestrutura física. Para redes completamente isoladas, será necessário configuração adicional de roteamento ou VPN.
```

[1](https://learn.microsoft.com/pt-br/azure/azure-arc/kubernetes/diagnose-connection-issues)
[2](https://stackoverflow.com/questions/74054955/powershell-pod-failing-in-kubernetes-cluster)
[3](https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/create-upgrade-delete/windows-cse-error-check-api-server-connectivity)
[4](https://www.techtarget.com/searchitoperations/tutorial/Manage-Kubernetes-clusters-with-PowerShell-and-kubectl)
[5](https://www.reddit.com/r/PowerShell/comments/124lodl/testing_a_port_range_through_testnetconnection/)
[6](https://docs.azure.cn/en-us/aks/kubernetes-walkthrough-powershell)
[7](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_completion/)
[8](https://www.linkedin.com/pulse/manage-kubernetes-resource-kubectl-powershell-trevor-sullivan)