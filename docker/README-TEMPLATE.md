# Template para README.md de Stacks Docker

Use este prompt para criar READMEs padronizados para todas as stacks Docker do projeto .BatOps.

> 🤖 **Compatibilidade com Agents**: Este template segue as especificações do [agents.md](https://agents.md/) para garantir máxima compatibilidade com sistemas de agentes e assistentes de IA.

## Prompt para Agent/Assistant

```text
Baseado na estrutura do README.md da stack n8n, crie um README.md completo seguindo exatamente este padrão.

IMPORTANTE: Este prompt segue as especificações agents.md (https://agents.md/) para garantir compatibilidade com sistemas de agentes de IA.

## Estrutura Obrigatória do README.md

### 1. Cabeçalho
- Título: `# [NOME_DA_STACK] com [TECNOLOGIAS_PRINCIPAIS]`
- **Tempo de Leitura**: Incluir estimativa de tempo de leitura baseada no conteúdo (ex: "⏱️ Tempo de leitura: ~8 minutos")

### 2. Seções Obrigatórias (nesta ordem):
1. **Propósito** - Descrição clara do objetivo da solução
2. **Motivação** - Lista com bullets das razões para usar esta abordagem
3. **Dependências** - Dividir em:
   - Sistema Operacional (Linux recomendado, macOS compatível, Windows com WSL2)
   - Obrigatórias (Docker >= 20.10, Docker Compose >= 2.0)
   - Opcionais (Git, editores)
4. **Diagrama da Solução** - Usar Mermaid para visualizar arquitetura
5. **Como Implantar e Configurar** - Incluir:
   - Seção 0: Configuração WSL para Windows
   - Seção 1: Preparação do Ambiente (clone do repositório)
   - Seções numeradas para cada etapa
6. **Recursos Criados e Configurados** - Tabelas organizadas
7. **Como Testar** - Testes de conectividade e funcionais
8. **Como Desinstalar** - Opções parciais e completas
9. **Problemas Comuns** - Guia de troubleshooting
10. **Logs Gerados** - Tabela com origem e localização
11. **Tecnologias de Terceiros Relacionadas** - Links para sites oficiais
12. **Isenção de Responsabilidade** - Cláusula AS-IS
13. **Licenças** - Todas as licenças envolvidas
14. **Autor** - Informações do DevOps Vanilla

## Diretrizes Específicas

### Sistema Operacional

SEMPRE incluir aviso sobre Windows:

```markdown
> ⚠️ **Importante para usuários Windows**: Este procedimento foi desenvolvido e testado para ambientes Linux. Para Windows, é **altamente recomendado** usar [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install) para garantir compatibilidade total com os scripts bash e comandos Docker.
```

### Preparação do Ambiente (Seção 1)

SEMPRE usar esta sequência exata:

```bash
# Ir para o diretório home
cd

# Clonar o repositório
git clone https://github.com/devopsvanilla/.BatOps.git

# Entrar diretamente no diretório da stack [NOME_STACK]
cd .BatOps/docker/[NOME_STACK]

# Copiar o arquivo de configuração de exemplo
cp .env.example .env
```

### Estrutura do Projeto

SEMPRE incluir esta nota no início da implantação:

```markdown
> 📂 **Estrutura do Projeto**: Este projeto faz parte do repositório [.BatOps](https://github.com/devopsvanilla/.BatOps) e está localizado no diretório `docker/[NOME_STACK]/`. Todos os comandos devem ser executados a partir deste diretório específico.
```

### Links e Referências

- SEMPRE incluir links para sites oficiais de todas as tecnologias mencionadas
- Usar formato: **[Nome da Tecnologia](https://link-oficial.com/)**

### Tempo de Leitura

- **Calcular automaticamente**: Estimar baseado no conteúdo do documento
- **Fórmula padrão**: ~200 palavras por minuto (velocidade média de leitura)
- **Posicionamento**: Logo após o título principal
- **Formato**: `⏱️ Tempo de leitura: ~X minutos`
- **Arredondamento**: Usar números inteiros (ex: ~8 minutos, não 7.5)

### Compliance

- **Agents.md**: Seguir especificações do [agents.md](https://agents.md/) para compatibilidade com sistemas de IA
- **Markdownlint**: Respeitar regras do markdownlint
- **Estrutura**: Usar hierarquia correta de cabeçalhos
- **Formatação**: Incluir quebra de linha no final do arquivo
- **Estilo**: Evitar emphasis como heading

### Autor Padrão

```markdown
# [NOME_DA_STACK] com [TECNOLOGIAS_PRINCIPAIS]

⏱️ Tempo de leitura: ~X minutos

## Propósito
[restante do conteúdo...]

## Autor

DevOps Vanilla

- GitHub: [@devopsvanilla](https://github.com/devopsvanilla)
- Projeto: [.BatOps](https://github.com/devopsvanilla/.BatOps)

---

Última atualização: [MÊS ANO]
```

## Variáveis para Personalizar

Ao usar este template, substitua:

- `[NOME_DA_STACK]` - Nome da stack (ex: "Grafana", "Jenkins", "ELK")
- `[TECNOLOGIAS_PRINCIPAIS]` - Tecnologias principais (ex: "Prometheus e AlertManager")
- `[NOME_STACK]` - Nome do diretório da stack (ex: "grafana", "jenkins", "elk")
- `[MÊS ANO]` - Data da última atualização (ex: "Setembro 2025")

## Comandos Padrão

### Para WSL (Seção 0)

```bash
# Instalar WSL2 (PowerShell como Administrador)
wsl --install

# Ou instalar distribuição específica
wsl --install -d Ubuntu

# Após instalação, entrar no WSL
wsl

# Instalar Docker no WSL
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Reiniciar sessão WSL
exit
wsl
```

### Para Testes Básicos

```bash
# Verificar se todos os containers estão rodando
docker-compose ps

# Testar conectividade HTTP (adaptar portas)
curl -f http://localhost:[PORTA] || echo "[SERVIÇO] não está respondendo"
```

### Para Troubleshooting Windows

```bash
# Verificar se está no WSL
wsl --status

# Verificar se Docker está rodando no WSL
docker --version
sudo service docker start

# Converter terminações de linha se necessário
dos2unix .env docker-compose.yaml
```

## Especificações Agents.md

Este prompt segue as diretrizes do [agents.md](https://agents.md/) que define padrões para:

- **Clareza de instruções**: Comandos específicos e não ambíguos
- **Estrutura consistente**: Hierarquia padronizada de informações
- **Reprodutibilidade**: Passos que podem ser executados por agentes de IA
- **Completude**: Todas as informações necessárias incluídas
- **Compatibilidade**: Formato que funciona com diversos sistemas de IA

### Princípios Agents.md Aplicados

- **Instruções específicas**: Cada seção tem diretrizes claras
- **Formatação padronizada**: Uso consistente de markdown
- **Comandos testáveis**: Todos os comandos podem ser executados
- **Estrutura previsível**: Ordem lógica e repetível
- **Metadados claros**: Informações sobre tecnologias e dependências

Este template garante consistência e completude em todas as stacks Docker do projeto .BatOps.

## Como Usar Este Template

### 1. Compatibilidade Agents.md

- Referência direta ao [agents.md](https://agents.md/)
- Especificações para compatibilidade com sistemas de IA
- Princípios aplicados do padrão agents.md

### 2. Template Completo

O arquivo contém:

- **Prompt padronizado** para agents/assistentes
- **Estrutura obrigatória** com todas as 14 seções
- **Diretrizes específicas** para cada seção
- **Comandos padrão** para WSL, testes e troubleshooting
- **Variáveis substituíveis** para personalização
- **Compliance** com markdownlint e agents.md

### 3. Principais Características

- **Agents.md compliant**: Seguindo as especificações oficiais
- **Reprodutível**: Agentes podem executar o template consistentemente
- **Padronizado**: Estrutura idêntica para todas as stacks
- **Testável**: Todos os comandos são funcionais
- **Completo**: Todas as informações necessárias incluídas

### 4. **Para Implementar Nova Stack**

1. **Copie o prompt** da seção "Prompt para Agent/Assistant"
2. **Substitua as variáveis**:
   - `[NOME_DA_STACK]` - Nome da stack (ex: "Grafana", "Jenkins", "ELK")
   - `[TECNOLOGIAS_PRINCIPAIS]` - Tecnologias principais (ex: "Prometheus e AlertManager")
   - `[NOME_STACK]` - Nome do diretório (ex: "grafana", "jenkins", "elk")
   - `[MÊS ANO]` - Data da atualização (ex: "Setembro 2025")
3. **Execute o prompt** em qualquer agent/assistant compatível
4. **Revise** se todas as 14 seções obrigatórias estão presentes
5. **Calcule e adicione** o tempo de leitura estimado (~200 palavras/minuto)
6. **Teste** os comandos fornecidos

### 5. Garantias do Template

✅ Seguir exatamente o padrão estabelecido  
✅ Ser compatível com sistemas de IA  
✅ Manter qualidade e completude  
✅ Respeitar as especificações agents.md  
✅ Incluir tempo de leitura estimado automaticamente  

**O template está pronto para ser usado por qualquer agent/assistant!** 🎉
