version: 2
ethernets:
  {{INTERFACE_NAME}}:
    dhcp4: false
    addresses:
      - {{IP_ADDRESS}}/{{CIDR}}
    routes:
      - to: default
        via: {{GATEWAY}}
    nameservers:
      addresses:
{{DNS_BLOCK}}
