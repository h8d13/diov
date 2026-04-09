#!/bin/bash
# Void Linux installer script - requires root and target disk as argument

# command -v 
# 
# deps=(
# 	curl
# )

set -e

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }
[[ -z "$1" ]] && { echo "Usage: $0 /dev/sdX"; exit 1; }

DISK="$1"

# Fetch and test mirrors
echo "Fetching mirror list..."
YAML=$(curl -s "https://raw.githubusercontent.com/void-linux/xmirror/master/mirrors.yaml")
mapfile -t MIRRORS < <(echo "$YAML" | grep -oP 'https?://[^"]+' | sed 's:/$::')
tmp=$(mktemp)
echo "Testing ${#MIRRORS[@]} mirrors..."
for m in "${MIRRORS[@]}"; do
  ( t=$(curl -o /dev/null -s -w '%{time_connect}' --connect-timeout 1 "$m/current" 2>/dev/null || echo 999); echo "$t $m" >> "$tmp" ) &
done
wait
fastest=$(sort -n "$tmp" | head -1 | cut -d' ' -f2)
rm "$tmp"
echo "Fastest: $fastest"
REPO="${fastest:-https://repo-default.voidlinux.org}/current"
echo "Using mirror: $REPO"

# Partition disk: 512M EFI + rest for root
parted -s "$DISK" mklabel gpt mkpart ESP fat32 1MiB 513MiB set 1 esp on mkpart root ext4 513MiB 100%
mkfs.vfat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"
mount "${DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi

# Install base system
XBPS_ARCH=x86_64 xbps-install -Sy -R "$REPO" -r /mnt base-system linux grub-x86_64-efi

# Configure system
echo "void" > /mnt/etc/hostname
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
cat > /mnt/etc/fstab <<EOF
${DISK}2 / ext4 defaults 0 1
${DISK}1 /boot/efi vfat defaults 0 2
EOF

# Install bootloader and set root password
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
echo "root:void" | chroot /mnt chpasswd

umount -R /mnt
echo "Installation complete. Root password is 'void'"
