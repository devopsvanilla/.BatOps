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
setup: ## Instala todas as dependências necessárias (requer sudo)
	@echo "⚙️  Iniciando setup agressivo do ambiente..."

	@echo "1. Instalando pre-commit..."
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y pre-commit || pip install --user pre-commit; \
	fi
	@pre-commit install
	@pre-commit install --hook-type commit-msg

	@echo "2. Instalando linters e ferramentas de segurança..."

	@# ShellCheck
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "   📦 Instalando shellcheck..."; \
		sudo apt update && sudo apt install -y shellcheck; \
	fi

	@# Hadolint
	@if ! command -v hadolint >/dev/null 2>&1; then \
		echo "   🐳 Instalando hadolint..."; \
		sudo wget -O /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64; \
		sudo chmod +x /usr/local/bin/hadolint; \
	fi

	@# Gitleaks
	@if ! command -v gitleaks >/dev/null 2>&1; then \
		echo "   🔐 Instalando gitleaks..."; \
		wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz; \
		tar -xzf gitleaks_8.18.2_linux_x64.tar.gz gitleaks; \
		sudo mv gitleaks /usr/local/bin/; \
		rm gitleaks_8.18.2_linux_x64.tar.gz; \
	fi

	@# Trivy
	@if ! command -v trivy >/dev/null 2>&1; then \
		echo "   🔍 Instalando trivy..."; \
		sudo apt-get install wget apt-transport-https gnupg lsb-release -y; \
		sudo rm -f /etc/apt/sources.list.d/trivy.list; \
		wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null; \
		echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $$(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list; \
		sudo apt-get update; \
		sudo apt-get install trivy -y; \
	fi

	@# markdownlint
	@if ! command -v markdownlint >/dev/null 2>&1; then \
		echo "   📝 Instalando markdownlint..."; \
		sudo env "PATH=$$PATH" $$(which npm) install -g markdownlint-cli; \
	fi

	@echo ""
	@echo "✅ Setup agressivo concluído com sucesso!"

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
