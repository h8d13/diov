#!/bin/bash
# Void Linux installer script - requires root and target disk as argument

set -e

[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }
[[ -z "$1" ]] && { echo "Usage: $0 /dev/sdX"; exit 1; }

DISK="$1"

# Find fastest mirror
MIRRORS=(
  "https://repo-fi.voidlinux.org" "https://repo-de.voidlinux.org" "https://repo-us.voidlinux.org"
  "https://repo-fastly.voidlinux.org" "https://mirrors.summithq.com/voidlinux" "https://mirrors.cicku.me/voidlinux"
  "https://mirror.ps.kz/voidlinux" "https://mirror.nju.edu.cn/voidlinux" "https://mirrors.bfsu.edu.cn/voidlinux"
  "https://mirrors.tuna.tsinghua.edu.cn/voidlinux" "https://mirror.sjtu.edu.cn/voidlinux"
  "https://mirrors.dotsrc.org/voidlinux" "https://ftp.cc.uoc.gr/mirrors/linux/voidlinux"
  "https://voidlinux.mirror.garr.it" "https://void.cijber.net" "https://void.sakamoto.pl"
  "https://mirror.yandex.ru/mirrors/voidlinux" "https://ftp.lysator.liu.se/pub/voidlinux"
  "https://mirror.accum.se/mirror/voidlinux" "https://mirror.puzzle.ch/voidlinux"
  "https://mirror.clarkson.edu/voidlinux" "https://mirrors.lug.mtu.edu/voidlinux"
  "https://mirror.aarnet.edu.au/pub/voidlinux" "https://ftp.swin.edu.au/voidlinux"
)
echo "Testing mirrors..."
fastest=""; best=999
for m in "${MIRRORS[@]}"; do
  t=$(curl -o /dev/null -s -w '%{time_total}' --connect-timeout 2 "$m/current" 2>/dev/null || echo 999)
  (( $(echo "$t < $best" | bc -l) )) && { best=$t; fastest=$m; }
done
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
