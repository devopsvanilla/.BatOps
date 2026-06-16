#cloud-config
hostname: {{HOSTNAME}}
fqdn: {{FQDN}}
manage_etc_hosts: {{MANAGE_ETC_HOSTS}}
preserve_hostname: {{PRESERVE_HOSTNAME}}
timezone: {{TIMEZONE}}
locale: {{LOCALE}}

disable_root: {{DISABLE_ROOT}}
ssh_pwauth: {{SSH_PWAUTH}}
package_update: {{PACKAGE_UPDATE}}
package_upgrade: {{PACKAGE_UPGRADE}}
package_reboot_if_required: {{PACKAGE_REBOOT_IF_REQUIRED}}

users:
{{USERS_BLOCK}}

packages:
{{PACKAGES_BLOCK}}

runcmd:
{{RUNCMD_BLOCK}}

final_message: |
  Cloud-init finalizado para {{HOSTNAME}}.
  Instance ID: {{INSTANCE_ID}}
  Perfil: {{PROFILE_NAME}}
  Virtualizador: {{VIRTUALIZER}}
