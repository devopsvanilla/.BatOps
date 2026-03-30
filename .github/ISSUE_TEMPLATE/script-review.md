---
name: 🔧 Padronização de Script Bash
about: Revisar e adicionar set -euo pipefail em scripts Bash
title: 'refactor: revisar set -euo pipefail nos scripts Bash'
labels: ['refactor', 'bash', 'tech-debt']
assignees: ''
---

## Descrição

Os scripts Bash do repositório precisam ser revisados individualmente para adicionar `set -euo pipefail` onde for seguro, garantindo comportamento robusto de tratamento de erros.

## Contexto

- Scripts já estão marcados com `# TODO: Revisar e adicionar set -euo pipefail — Issue #1`
- A flag `-u` (nounset) pode quebrar scripts que usam variáveis opcionais como `$1` sem verificação prévia
- A flag `-o pipefail` pode alterar comportamento em pipelines com `grep` que retorna 1 quando não encontra

## Scripts a Revisar

Buscar todos os scripts marcados com TODO:

```bash
grep -rl '# TODO.*set -euo pipefail' --include='*.sh' .
```

## Checklist por Script

Para cada script:

- [ ] Verificar se usa variáveis posicionais opcionais (`$1`, `$2`, etc.)
- [ ] Verificar se usa pipelines com `grep` que podem retornar 1
- [ ] Verificar tratamento de erros com `|| true` onde necessário
- [ ] Adicionar `set -euo pipefail` ou documentar por que não é possível
- [ ] Remover o comentário `# TODO`
- [ ] Testar o script após a alteração
