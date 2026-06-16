#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT_DIR="$SCRIPT_DIR/cloud-init"
PROFILE_DIR="$CLOUD_INIT_DIR/profiles"
TEMPLATE_DIR="$CLOUD_INIT_DIR/templates"
LIB_DIR="$CLOUD_INIT_DIR/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/profile.sh"
source "$LIB_DIR/render.sh"
source "$LIB_DIR/image.sh"

PROFILE_NAME=""
PROFILE_FILE=""
VIRTUALIZER=""
OUTPUT_DIR=""
VM_NAME=""
HOSTNAME_VALUE=""
FQDN=""
INSTANCE_ID=""
PRIMARY_USER=""
PASSWORD_VALUE=""
SSH_KEY_FILE=""
SSH_KEY_CONTENT=""
AUTH_MODE=""
NETWORK_MODE=""
INTERFACE_NAME=""
IP_ADDRESS=""
CIDR=""
GATEWAY=""
DNS_CSV=""
TIMEZONE_OVERRIDE=""
LOCALE_OVERRIDE=""
GENERATE_ISO="true"
NON_INTERACTIVE="false"

usage() {
	cat <<'EOF'
Uso: ./generate-cloudinit.sh [opções]

Gera artefatos NoCloud cloud-init para o perfil informado e cria uma ISO compatível
com o virtualizador selecionado. Nesta primeira versão, o virtualizador suportado é:
  - proxmox

Opções:
  --profile NOME              Nome do perfil em linux-utils/cloud-init/profiles (ex.: ubuntu-24.04)
  --profile-file CAMINHO      Caminho absoluto ou relativo de um perfil YAML customizado
  --virtualizer NOME          Virtualizador alvo (atualmente: proxmox)
  --output-dir CAMINHO        Diretório de saída para os artefatos gerados
  --vm-name NOME              Nome da VM para fins de organização dos artefatos
  --hostname NOME             Hostname da instância
  --fqdn NOME                 FQDN da instância
  --instance-id ID            Instance ID para o meta-data
  --username NOME             Usuário administrador a ser criado
  --auth-mode MODO            password | key | both
  --password SENHA            Senha do usuário administrador
  --ssh-key-file CAMINHO      Caminho de uma chave pública SSH
  --network-mode MODO         dhcp | static
  --interface NOME            Interface para o network-config (ex.: ens18)
  --ip-address IP             Endereço IPv4 estático
  --cidr N                    Máscara em CIDR (ex.: 24)
  --gateway IP                Gateway IPv4
  --dns LISTA                 Lista CSV de DNS (ex.: 1.1.1.1,8.8.8.8)
  --timezone TZ               Override de timezone
  --locale LOCALE             Override de locale
  --no-iso                    Gera apenas os arquivos cloud-init, sem criar a seed ISO
  --non-interactive           Falha caso falte algum valor obrigatório
  --list-profiles             Lista perfis disponíveis
  -h, --help                  Mostra esta ajuda

Exemplos:
  ./generate-cloudinit.sh
  ./generate-cloudinit.sh --profile ubuntu-24.04 --virtualizer proxmox --non-interactive \
	--vm-name ubuntu-lab --hostname ubuntu-lab --fqdn ubuntu-lab.local \
	--username ops --auth-mode both --password 'TroqueEstaSenha123!' \
	--ssh-key-file ~/.ssh/id_ed25519.pub --network-mode dhcp
EOF
}

list_profiles() {
	local profile_file
	log_info "Perfis disponíveis:"
	while IFS= read -r profile_file; do
		printf '  - %s\n' "$(basename "$profile_file" .yaml)"
	done < <(list_profile_files "$PROFILE_DIR")
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--profile)
				PROFILE_NAME="$2"
				shift 2
				;;
			--profile-file)
				PROFILE_FILE="$2"
				shift 2
				;;
			--virtualizer)
				VIRTUALIZER="$2"
				shift 2
				;;
			--output-dir)
				OUTPUT_DIR="$2"
				shift 2
				;;
			--vm-name)
				VM_NAME="$2"
				shift 2
				;;
			--hostname)
				HOSTNAME_VALUE="$2"
				shift 2
				;;
			--fqdn)
				FQDN="$2"
				shift 2
				;;
			--instance-id)
				INSTANCE_ID="$2"
				shift 2
				;;
			--username)
				PRIMARY_USER="$2"
				shift 2
				;;
			--auth-mode)
				AUTH_MODE="$2"
				shift 2
				;;
			--password)
				PASSWORD_VALUE="$2"
				shift 2
				;;
			--ssh-key-file)
				SSH_KEY_FILE="$2"
				shift 2
				;;
			--network-mode)
				NETWORK_MODE="$2"
				shift 2
				;;
			--interface)
				INTERFACE_NAME="$2"
				shift 2
				;;
			--ip-address)
				IP_ADDRESS="$2"
				shift 2
				;;
			--cidr)
				CIDR="$2"
				shift 2
				;;
			--gateway)
				GATEWAY="$2"
				shift 2
				;;
			--dns)
				DNS_CSV="$2"
				shift 2
				;;
			--timezone)
				TIMEZONE_OVERRIDE="$2"
				shift 2
				;;
			--locale)
				LOCALE_OVERRIDE="$2"
				shift 2
				;;
			--no-iso)
				GENERATE_ISO="false"
				shift
				;;
			--non-interactive)
				NON_INTERACTIVE="true"
				shift
				;;
			--list-profiles)
				list_profiles
				exit 0
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				fail "Opção inválida: $1"
				;;
		esac
	done
}

require_value() {
	local value="$1"
	local label="$2"
	[[ -n "$value" ]] || fail "Valor obrigatório ausente: $label"
}

select_profile() {
	if [[ -n "$PROFILE_FILE" ]]; then
		[[ -f "$PROFILE_FILE" ]] || fail "Perfil não encontrado: $PROFILE_FILE"
		return 0
	fi

	if [[ -n "$PROFILE_NAME" ]]; then
		PROFILE_FILE="$(resolve_profile_path "$PROFILE_DIR" "$PROFILE_NAME")" || fail "Perfil não encontrado: $PROFILE_NAME"
		return 0
	fi

	if [[ "$NON_INTERACTIVE" == "true" ]]; then
		fail "Informe --profile ou --profile-file no modo não interativo."
	fi

	local available_profiles=()
	local profile_path
	while IFS= read -r profile_path; do
		available_profiles+=("$(basename "$profile_path" .yaml)")
	done < <(list_profile_files "$PROFILE_DIR")

	[[ ${#available_profiles[@]} -gt 0 ]] || fail "Nenhum perfil encontrado em $PROFILE_DIR"

	PROFILE_NAME="$(prompt_choice 'Selecione o perfil do sistema operacional:' "${available_profiles[0]}" "${available_profiles[@]}")"
	PROFILE_FILE="$(resolve_profile_path "$PROFILE_DIR" "$PROFILE_NAME")" || fail "Perfil não encontrado: $PROFILE_NAME"
}

load_profile_defaults() {
	PROFILE_NAME="$(basename "$PROFILE_FILE" .yaml)"
	PROFILE_DISPLAY_NAME="$(yaml_get_scalar "$PROFILE_FILE" 'profile.name')"
	PROFILE_DEFAULT_VIRTUALIZER="$(yaml_get_scalar "$PROFILE_FILE" 'virtualizer.default')"
	PROFILE_DEFAULT_INTERFACE="$(yaml_get_scalar "$PROFILE_FILE" 'virtualizer.proxmox.default_interface')"
	PROFILE_VOLUME_LABEL="$(yaml_get_scalar "$PROFILE_FILE" 'virtualizer.proxmox.default_volume_label')"
	PROFILE_DEFAULT_TIMEZONE="$(yaml_get_scalar "$PROFILE_FILE" 'system.timezone')"
	PROFILE_DEFAULT_LOCALE="$(yaml_get_scalar "$PROFILE_FILE" 'system.locale')"
	PROFILE_PACKAGE_UPDATE="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'system.package_update')")"
	PROFILE_PACKAGE_UPGRADE="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'system.package_upgrade')")"
	PROFILE_PACKAGE_REBOOT="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'system.package_reboot_if_required')")"
	PROFILE_MANAGE_ETC_HOSTS="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'system.manage_etc_hosts')")"
	PROFILE_PRESERVE_HOSTNAME="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'system.preserve_hostname')")"
	PROFILE_NETWORK_MODE="$(yaml_get_scalar "$PROFILE_FILE" 'network.default_mode')"
	PROFILE_AUTH_DEFAULT_USER="$(yaml_get_scalar "$PROFILE_FILE" 'auth.default_user')"
	PROFILE_AUTH_DEFAULT_SHELL="$(yaml_get_scalar "$PROFILE_FILE" 'auth.default_shell')"
	PROFILE_DISABLE_ROOT="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'auth.disable_root')")"
	PROFILE_LOCK_PASSWD_IF_SSH_ONLY="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'auth.lock_passwd_if_ssh_only')")"
	PROFILE_KEEP_DEFAULT_USER="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'auth.keep_default_user')")"
	PROFILE_SSH_PWAUTH_DEFAULT="$(yaml_bool "$(yaml_get_scalar "$PROFILE_FILE" 'auth.ssh_password_auth')")"
	mapfile -t PROFILE_DEFAULT_GROUPS < <(yaml_get_list "$PROFILE_FILE" 'auth.default_groups')
	mapfile -t PROFILE_DEFAULT_DNS < <(yaml_get_list "$PROFILE_FILE" 'network.default_dns')
	mapfile -t PROFILE_PACKAGES < <(yaml_get_list "$PROFILE_FILE" 'packages.base')
	mapfile -t PROFILE_RUNCMD_BASE < <(yaml_get_list "$PROFILE_FILE" 'runcmd.base')
	mapfile -t PROFILE_RUNCMD_PASSWORD_AUTH < <(yaml_get_list "$PROFILE_FILE" 'runcmd.password_auth')
}

prompt_if_missing() {
	VIRTUALIZER="${VIRTUALIZER:-$PROFILE_DEFAULT_VIRTUALIZER}"
	if [[ -z "$VIRTUALIZER" ]]; then
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			fail "Informe o virtualizador com --virtualizer."
		fi
		VIRTUALIZER="$(prompt_choice 'Selecione o virtualizador alvo:' proxmox proxmox)"
	fi

	[[ "$VIRTUALIZER" == "proxmox" ]] || fail "Virtualizador ainda não suportado nesta versão: $VIRTUALIZER"

	if [[ -z "$VM_NAME" ]]; then
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			fail "Informe --vm-name no modo não interativo."
		fi
		VM_NAME="$(prompt_with_default 'Nome da VM' "$PROFILE_NAME")"
	fi

	if [[ -z "$HOSTNAME_VALUE" ]]; then
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			fail "Informe --hostname no modo não interativo."
		fi
		HOSTNAME_VALUE="$(prompt_with_default 'Hostname' "$VM_NAME")"
	fi

	if [[ -z "$FQDN" ]]; then
		local default_fqdn="${HOSTNAME_VALUE}.local"
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			FQDN="$default_fqdn"
		else
			FQDN="$(prompt_with_default 'FQDN' "$default_fqdn")"
		fi
	fi

	if [[ -z "$INSTANCE_ID" ]]; then
		INSTANCE_ID="iid-$(slugify "$VM_NAME")"
	fi

	if [[ -z "$PRIMARY_USER" ]]; then
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			PRIMARY_USER="$PROFILE_AUTH_DEFAULT_USER"
		else
			PRIMARY_USER="$(prompt_with_default 'Usuário administrador' "$PROFILE_AUTH_DEFAULT_USER")"
		fi
	fi

	if [[ -z "$AUTH_MODE" ]]; then
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			fail "Informe --auth-mode no modo não interativo."
		fi
		AUTH_MODE="$(prompt_choice 'Modo de autenticação SSH:' both password key both)"
	fi

	if [[ "$AUTH_MODE" != "password" && "$AUTH_MODE" != "key" && "$AUTH_MODE" != "both" ]]; then
		fail "Modo de autenticação inválido: $AUTH_MODE"
	fi

	if [[ "$AUTH_MODE" == "password" || "$AUTH_MODE" == "both" ]]; then
		if [[ -z "$PASSWORD_VALUE" ]]; then
			if [[ "$NON_INTERACTIVE" == "true" ]]; then
				fail "Informe --password para o modo $AUTH_MODE."
			fi
			PASSWORD_VALUE="$(prompt_secret_optional 'Senha do usuário administrador')"
			[[ -n "$PASSWORD_VALUE" ]] || fail "Senha não pode ser vazia para o modo $AUTH_MODE."
		fi
	fi

	if [[ "$AUTH_MODE" == "key" || "$AUTH_MODE" == "both" ]]; then
		if [[ -z "$SSH_KEY_FILE" ]]; then
			if [[ "$NON_INTERACTIVE" == "true" ]]; then
				fail "Informe --ssh-key-file para o modo $AUTH_MODE."
			fi
			SSH_KEY_FILE="$(prompt_with_default 'Caminho da chave pública SSH' "$HOME/.ssh/id_ed25519.pub")"
		fi
		[[ -f "$SSH_KEY_FILE" ]] || fail "Chave pública SSH não encontrada: $SSH_KEY_FILE"
		SSH_KEY_CONTENT="$(tr -d '\n' < "$SSH_KEY_FILE")"
	fi

	NETWORK_MODE="${NETWORK_MODE:-$PROFILE_NETWORK_MODE}"
	if [[ -z "$NETWORK_MODE" ]]; then
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			fail "Informe --network-mode."
		fi
		NETWORK_MODE="$(prompt_choice 'Modo de rede:' dhcp dhcp static)"
	fi

	if [[ "$NETWORK_MODE" != "dhcp" && "$NETWORK_MODE" != "static" ]]; then
		fail "Modo de rede inválido: $NETWORK_MODE"
	fi

	TIMEZONE_OVERRIDE="${TIMEZONE_OVERRIDE:-$PROFILE_DEFAULT_TIMEZONE}"
	LOCALE_OVERRIDE="${LOCALE_OVERRIDE:-$PROFILE_DEFAULT_LOCALE}"

	if [[ "$NON_INTERACTIVE" != "true" ]]; then
		TIMEZONE_OVERRIDE="$(prompt_with_default 'Timezone' "$TIMEZONE_OVERRIDE")"
		LOCALE_OVERRIDE="$(prompt_with_default 'Locale' "$LOCALE_OVERRIDE")"
	fi

	if [[ "$NETWORK_MODE" == "static" ]]; then
		INTERFACE_NAME="${INTERFACE_NAME:-$PROFILE_DEFAULT_INTERFACE}"
		if [[ "$NON_INTERACTIVE" != "true" ]]; then
			INTERFACE_NAME="$(prompt_with_default 'Interface de rede' "$INTERFACE_NAME")"
			IP_ADDRESS="${IP_ADDRESS:-$(prompt_with_default 'Endereço IPv4' '')}"
			CIDR="${CIDR:-$(prompt_with_default 'CIDR' '24')}"
			GATEWAY="${GATEWAY:-$(prompt_with_default 'Gateway' '')}"
			if [[ -z "$DNS_CSV" ]]; then
				DNS_CSV="$(prompt_with_default 'DNS (CSV)' "$(join_by ',' "${PROFILE_DEFAULT_DNS[@]}")")"
			fi
		fi
	fi

	if [[ -z "$OUTPUT_DIR" ]]; then
		local default_output_dir
		default_output_dir="$SCRIPT_DIR/cloud-init/output/$(slugify "$HOSTNAME_VALUE")"
		if [[ "$NON_INTERACTIVE" == "true" ]]; then
			OUTPUT_DIR="$default_output_dir"
		else
			OUTPUT_DIR="$(prompt_with_default 'Diretório de saída' "$default_output_dir")"
		fi
	fi
}

validate_inputs() {
	require_value "$PROFILE_FILE" 'profile-file'
	require_value "$VIRTUALIZER" 'virtualizer'
	require_value "$VM_NAME" 'vm-name'
	require_value "$HOSTNAME_VALUE" 'hostname'
	require_value "$PRIMARY_USER" 'username'

	validate_hostname "$HOSTNAME_VALUE" || fail "Hostname inválido: $HOSTNAME_VALUE"
	validate_username "$PRIMARY_USER" || fail "Nome de usuário inválido: $PRIMARY_USER"

	if [[ "$NETWORK_MODE" == "static" ]]; then
		require_value "$INTERFACE_NAME" 'interface'
		require_value "$IP_ADDRESS" 'ip-address'
		require_value "$CIDR" 'cidr'
		require_value "$GATEWAY" 'gateway'

		validate_ipv4 "$IP_ADDRESS" || fail "IPv4 inválido: $IP_ADDRESS"
		validate_cidr "$CIDR" || fail "CIDR inválido: $CIDR"
		validate_ipv4 "$GATEWAY" || fail "Gateway inválido: $GATEWAY"
	fi

	if [[ -n "$DNS_CSV" ]]; then
		IFS=',' read -r -a DNS_VALUES <<< "$DNS_CSV"
		local dns_ip
		for dns_ip in "${DNS_VALUES[@]}"; do
			dns_ip="$(trim "$dns_ip")"
			validate_ipv4 "$dns_ip" || fail "DNS inválido: $dns_ip"
		done
	else
		DNS_VALUES=("${PROFILE_DEFAULT_DNS[@]}")
	fi
}

render_artifacts() {
	mkdir -p "$OUTPUT_DIR"

	local password_hash=""
	local disable_password_login="false"
	local ssh_pwauth="$PROFILE_SSH_PWAUTH_DEFAULT"
	local runcmd_values=("${PROFILE_RUNCMD_BASE[@]}")

	if [[ "$AUTH_MODE" == "key" ]]; then
		ssh_pwauth="false"
		disable_password_login="$PROFILE_LOCK_PASSWD_IF_SSH_ONLY"
	else
		ssh_pwauth="true"
		password_hash="$(generate_password_hash "$PASSWORD_VALUE")"
		if [[ "$AUTH_MODE" == "both" || "$AUTH_MODE" == "password" ]]; then
			runcmd_values+=("${PROFILE_RUNCMD_PASSWORD_AUTH[@]}")
		fi
	fi

	if [[ "$AUTH_MODE" == "both" ]]; then
		disable_password_login="false"
	fi

	local groups_csv
	groups_csv="$(join_by ', ' "${PROFILE_DEFAULT_GROUPS[@]}")"

	local users_block
	users_block="$(build_users_block "$PROFILE_KEEP_DEFAULT_USER" "$PROFILE_AUTH_DEFAULT_USER" "$PRIMARY_USER" "$password_hash" "$PROFILE_AUTH_DEFAULT_SHELL" "$disable_password_login" "$groups_csv" "$SSH_KEY_CONTENT")"

	local packages_block
	packages_block="$(build_yaml_list_block '  ' "${PROFILE_PACKAGES[@]}")"

	local runcmd_block
	runcmd_block="$(build_runcmd_block "${runcmd_values[@]}")"

	local user_data_path="$OUTPUT_DIR/user-data"
	local meta_data_path="$OUTPUT_DIR/meta-data"
	local network_config_path=""

	render_template "$TEMPLATE_DIR/user-data.yaml.tpl" "$user_data_path" \
		HOSTNAME "$HOSTNAME_VALUE" \
		FQDN "$FQDN" \
		MANAGE_ETC_HOSTS "$PROFILE_MANAGE_ETC_HOSTS" \
		PRESERVE_HOSTNAME "$PROFILE_PRESERVE_HOSTNAME" \
		TIMEZONE "$TIMEZONE_OVERRIDE" \
		LOCALE "$LOCALE_OVERRIDE" \
		DISABLE_ROOT "$PROFILE_DISABLE_ROOT" \
		SSH_PWAUTH "$ssh_pwauth" \
		PACKAGE_UPDATE "$PROFILE_PACKAGE_UPDATE" \
		PACKAGE_UPGRADE "$PROFILE_PACKAGE_UPGRADE" \
		PACKAGE_REBOOT_IF_REQUIRED "$PROFILE_PACKAGE_REBOOT" \
		USERS_BLOCK "$users_block" \
		PACKAGES_BLOCK "$packages_block" \
		RUNCMD_BLOCK "$runcmd_block" \
		INSTANCE_ID "$INSTANCE_ID" \
		PROFILE_NAME "$PROFILE_DISPLAY_NAME" \
		VIRTUALIZER "$VIRTUALIZER"

	render_template "$TEMPLATE_DIR/meta-data.yaml.tpl" "$meta_data_path" \
		INSTANCE_ID "$INSTANCE_ID" \
		HOSTNAME "$HOSTNAME_VALUE"

	if [[ "$NETWORK_MODE" == "static" ]]; then
		network_config_path="$OUTPUT_DIR/network-config"
		local dns_block
		dns_block="$(build_dns_block "${DNS_VALUES[@]}")"
		render_template "$TEMPLATE_DIR/network-config.yaml.tpl" "$network_config_path" \
			INTERFACE_NAME "$INTERFACE_NAME" \
			IP_ADDRESS "$IP_ADDRESS" \
			CIDR "$CIDR" \
			GATEWAY "$GATEWAY" \
			DNS_BLOCK "$dns_block"
	fi

	GENERATED_USER_DATA_PATH="$user_data_path"
	GENERATED_META_DATA_PATH="$meta_data_path"
	GENERATED_NETWORK_CONFIG_PATH="$network_config_path"
}

generate_seed_image() {
	[[ "$GENERATE_ISO" == "true" ]] || return 0

	local iso_path
	iso_path="$OUTPUT_DIR/$(slugify "$HOSTNAME_VALUE")-seed.iso"
	if create_seed_image "$iso_path" "$PROFILE_VOLUME_LABEL" "$GENERATED_USER_DATA_PATH" "$GENERATED_META_DATA_PATH" "$GENERATED_NETWORK_CONFIG_PATH"; then
		GENERATED_ISO_PATH="$iso_path"
		return 0
	fi

	fail "Não foi possível gerar a seed ISO. Instale cloud-image-utils (cloud-localds) ou genisoimage/mkisofs/xorriso."
}

write_virtualizer_notes() {
	local notes_path="$OUTPUT_DIR/proxmox-attach.txt"

	cat > "$notes_path" <<EOF
Artefatos gerados para uso com Proxmox
=====================================

Arquivos:
- user-data: $GENERATED_USER_DATA_PATH
- meta-data: $GENERATED_META_DATA_PATH
${GENERATED_NETWORK_CONFIG_PATH:+- network-config: $GENERATED_NETWORK_CONFIG_PATH}
${GENERATED_ISO_PATH:+- seed ISO: $GENERATED_ISO_PATH}

Como usar:
1. Envie a ISO gerada para um storage de ISO do Proxmox.
2. Anexe a ISO à VM como CD-ROM ou mídia cloud-init NoCloud.
3. Garanta que a VM use a cloud image Ubuntu correspondente ao perfil.

Exemplo genérico:
  qm set <VMID> --ide2 <ISO_STORAGE>:iso/$(basename "${GENERATED_ISO_PATH:-seed.iso}"),media=cdrom

Observação:
- O diretório de storage ISO varia por ambiente, então ele não é hardcoded aqui.
- Se usar IP estático, o arquivo network-config já foi incluído na ISO NoCloud.
EOF
}

print_summary() {
	echo
	log_success "Artefatos cloud-init gerados com sucesso"
	echo "----------------------------------------"
	echo "Perfil.............: $PROFILE_DISPLAY_NAME"
	echo "Virtualizador......: $VIRTUALIZER"
	echo "VM.................: $VM_NAME"
	echo "Hostname...........: $HOSTNAME_VALUE"
	echo "FQDN...............: $FQDN"
	echo "Usuário............: $PRIMARY_USER"
	echo "Rede...............: $NETWORK_MODE"
	echo "Saída..............: $OUTPUT_DIR"
	echo "user-data..........: $GENERATED_USER_DATA_PATH"
	echo "meta-data..........: $GENERATED_META_DATA_PATH"
	if [[ -n "$GENERATED_NETWORK_CONFIG_PATH" ]]; then
		echo "network-config.....: $GENERATED_NETWORK_CONFIG_PATH"
	fi
	if [[ -n "${GENERATED_ISO_PATH:-}" ]]; then
		echo "seed ISO...........: $GENERATED_ISO_PATH"
	fi
	echo "----------------------------------------"
}

main() {
	parse_args "$@"
	select_profile
	load_profile_defaults
	prompt_if_missing
	validate_inputs
	render_artifacts
	generate_seed_image
	write_virtualizer_notes
	print_summary
}

main "$@"
