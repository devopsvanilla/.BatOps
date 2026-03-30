.PHONY: help lint security setup test docs clean

# ─── Variáveis ───
SHELL_FILES := $(shell find . -name '*.sh' -not -path './.git/*' -not -path '*/ovftool/*')
DOCKERFILES := $(shell find . -name 'Dockerfile' -not -path './.git/*')

# ─── Ajuda (default) ───
help: ## Exibe esta ajuda
	@echo ""
	@echo "🦇 BatOps — Makefile"
	@echo "===================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ─── Lint ───
lint: lint-shell lint-docker lint-markdown ## Executa todos os linters

lint-shell: ## Lint de scripts Bash com ShellCheck
	@echo "🐚 Executando ShellCheck..."
	@shellcheck --severity=warning $(SHELL_FILES) && \
		echo "✅ ShellCheck: OK" || \
		echo "❌ ShellCheck: erros encontrados"

lint-docker: ## Lint de Dockerfiles com Hadolint
	@echo "🐳 Executando Hadolint..."
	@if [ -n "$(DOCKERFILES)" ]; then \
		for f in $(DOCKERFILES); do \
			echo "  Linting: $$f"; \
			hadolint $$f || true; \
		done; \
		echo "✅ Hadolint: concluído"; \
	else \
		echo "ℹ️  Nenhum Dockerfile encontrado"; \
	fi

lint-markdown: ## Lint de arquivos Markdown
	@echo "📝 Executando markdownlint..."
	@markdownlint '**/*.md' --ignore node_modules && \
		echo "✅ markdownlint: OK" || \
		echo "❌ markdownlint: erros encontrados"

# ─── Segurança ───
security: security-secrets security-sca ## Executa todos os scans de segurança

security-secrets: ## Detecta segredos no código com Gitleaks
	@echo "🔐 Executando Gitleaks..."
	@gitleaks detect --source . --verbose && \
		echo "✅ Gitleaks: nenhum segredo encontrado" || \
		echo "❌ Gitleaks: segredos detectados!"

security-sca: ## Scan de vulnerabilidades com Trivy
	@echo "🔍 Executando Trivy..."
	@trivy fs --severity CRITICAL,HIGH . && \
		echo "✅ Trivy: concluído" || \
		echo "❌ Trivy: vulnerabilidades encontradas"

# ─── Setup ───
setup: ## Configura ambiente de desenvolvimento
	@echo "⚙️  Configurando ambiente..."
	@echo "1. Instalando pre-commit hooks..."
	@pre-commit install
	@pre-commit install --hook-type commit-msg
	@echo "2. Verificando dependências..."
	@command -v shellcheck >/dev/null 2>&1 && echo "   ✅ shellcheck" || echo "   ❌ shellcheck (instale: apt install shellcheck)"
	@command -v hadolint >/dev/null 2>&1 && echo "   ✅ hadolint" || echo "   ❌ hadolint (instale: https://github.com/hadolint/hadolint)"
	@command -v gitleaks >/dev/null 2>&1 && echo "   ✅ gitleaks" || echo "   ❌ gitleaks (instale: https://github.com/gitleaks/gitleaks)"
	@command -v trivy >/dev/null 2>&1 && echo "   ✅ trivy" || echo "   ❌ trivy (instale: https://github.com/aquasecurity/trivy)"
	@command -v markdownlint >/dev/null 2>&1 && echo "   ✅ markdownlint" || echo "   ❌ markdownlint (instale: npm install -g markdownlint-cli)"
	@echo ""
	@echo "✅ Setup concluído!"

# ─── Testes ───
test: ## Executa testes (validação básica dos scripts)
	@echo "🧪 Validando scripts..."
	@errors=0; \
	for f in $(SHELL_FILES); do \
		bash -n "$$f" 2>/dev/null || { echo "❌ Erro de sintaxe: $$f"; errors=$$((errors+1)); }; \
	done; \
	if [ $$errors -eq 0 ]; then echo "✅ Todos os scripts são sintaticamente válidos"; fi

# ─── Documentação ───
docs: ## Valida documentação
	@echo "📖 Verificando documentação..."
	@echo "  README.md:       $$([ -f README.md ] && echo '✅' || echo '❌')"
	@echo "  CONTRIBUTING.md: $$([ -f CONTRIBUTING.md ] && echo '✅' || echo '❌')"
	@echo "  THIRDPARTY.md:   $$([ -f THIRDPARTY.md ] && echo '✅' || echo '❌')"
	@echo "  LICENSE:         $$([ -f LICENSE ] && echo '✅' || echo '❌')"
	@echo "  .editorconfig:   $$([ -f .editorconfig ] && echo '✅' || echo '❌')"

# ─── TODOs ───
todos: ## Lista todos os TODOs no código
	@echo "📋 TODOs encontrados:"
	@grep -rn '# TODO' --include='*.sh' --include='*.py' . | grep -v '.git/' || echo "  Nenhum TODO encontrado 🎉"

# ─── Limpeza ───
clean: ## Remove arquivos temporários
	@echo "🧹 Limpando..."
	@find . -name '*.swp' -o -name '*.swo' -o -name '*~' | xargs rm -f 2>/dev/null || true
	@echo "✅ Limpeza concluída"
