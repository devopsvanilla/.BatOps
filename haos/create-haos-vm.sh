#!/usr/bin/env bash
set -e

echo "=== Assistente de criação de VM Home Assistant OS (qcow2) no Proxmox ==="

read -p "ID da VM (VMID) [120]: " VMID
VMID=${VMID:-120}

read -p "Nome da VM [haos]: " VMNAME
VMNAME=${VMNAME:-haos}

read -p "Caminho da imagem QCOW2 [/tmp/haos_ova-16.3.qcow2]: " QCOW
QCOW=${QCOW:-/tmp/haos_ova-16.3.qcow2}

read -p "Storage de disco para a VM (ex: local-lvm, lab-lvm) [local-lvm]: " DISKSTOR
DISKSTOR=${DISKSTOR:-local-lvm}

read -p "Bridge de rede (ex: vmbr0) [vmbr0]: " BRIDGE
BRIDGE=${BRIDGE:-vmbr0}

read -p "Memória RAM em MB [4096]: " RAM
RAM=${RAM:-4096}

read -p "Número de vCPUs [2]: " CORES
CORES=${CORES:-2}

read -p "Tamanho mínimo do disco (qm resize) [32G]: " DISKSIZE
DISKSIZE=${DISKSIZE:-32G}

echo ""
echo "Resumo da configuração:"
echo "  VMID      : $VMID"
echo "  Nome      : $VMNAME"
echo "  QCOW2     : $QCOW"
echo "  Storage   : $DISKSTOR"
echo "  Bridge    : $BRIDGE"
echo "  RAM       : ${RAM} MB"
echo "  vCPUs     : $CORES"
echo "  Disk min. : $DISKSIZE"
echo ""
read -p "Confirmar e criar a VM? [s/N]: " CONFIRM
CONFIRM=${CONFIRM:-n}

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
  echo "Operação cancelada."
  exit 1
fi

if [[ ! -f "$QCOW" ]]; then
  echo "ERRO: Arquivo QCOW2 não encontrado em: $QCOW"
  exit 1
fi

echo ">> Criando VM $VMID ($VMNAME)..."

qm create "$VMID" \
  --name "$VMNAME" \
  --memory "$RAM" \
  --cores "$CORES" \
  --net0 "virtio,bridge=$BRIDGE" \
  --machine q35 \
  --bios ovmf \
  --efidisk0 "${DISKSTOR}:0,format=raw,efitype=4m,pre-enrolled-keys=0" \
  --scsihw virtio-scsi-pci

echo ">> Importando disco QCOW2 para o storage $DISKSTOR..."
qm importdisk "$VMID" "$QCOW" "$DISKSTOR" --format qcow2

DISKID="vm-${VMID}-disk-0"

echo ">> Anexando disco importado como scsi0 e configurando boot..."
qm set "$VMID" --scsi0 "${DISKSTOR}:${DISKID}"
qm set "$VMID" --boot order=scsi0
qm set "$VMID" --scsihw virtio-scsi-pci

echo ">> Redimensionando disco para no mínimo $DISKSIZE..."
qm resize "$VMID" scsi0 "$DISKSIZE" || echo "Aviso: resize falhou (talvez imagem já seja >= $DISKSIZE)."

echo ">> Iniciando VM $VMID..."
qm start "$VMID"

echo "=== Concluído. Acompanhe o boot pelo console da VM na interface web do Proxmox. ==="
