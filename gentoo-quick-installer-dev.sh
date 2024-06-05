#!/bin/bash

set -e

HOSTNAME=${HOSTNAME:-TestServer710}

# Uncomment CUSTOM_MIRROR to use a custom mirror, if commented the default gentoo mirror will be used
CUSTOM_MIRROR=http://mirror.mylocaldomain.net/gentoo
GENTOO_MIRROR=${CUSTOM_MIRROR:-http://distfiles.gentoo.org}

# Set your region server
RSYNC_MIRROR=rsync.europe.gentoo.org

# Systemd is not tested (or supported) yet
INIT=${INIT:-openrc}

# Architecture to use, available option are amd64 (not tested anything else)
GENTOO_ARCH=${GENTOO_ARCH:-amd64}

# Stage to use, available options are STAGE3, STAGE4, RSYNC
STAGE=${STAGE:-STAGE3}
STAGE4_VERSION=${STAGE4_VERSION:-latest}

# IP to the rsync server
RSYNC_HOST=${RSYNC_HOST:-172.18.0.255}
RSYNC_PASS=${RSYNC_PASS:-pass123}

# List of distcc servers to use (space separated)m emtpy to disable, if enabled distcc wil also be installed
GENTOO_DISTCC="${GENTOO_DISTCC:-172.18.0.51/4 172.18.0.52/4 172.18.0.53/4 172.18.0.54/4 172.18.0.255/16}"
# Number of distcc cpu's 
GENTOO_DISTCC_NUM=${GENTOO_DISTCC_NUM:-32}

# Target disk to install to, default is /dev/sda but some virtual machines might use /dev/vda
TARGET_DISK=${TARGET_DISK:-/dev/sda}
TARGET_BOOT_SIZE=${TARGET_BOOT_SIZE:-1G}
TARGET_SWAP_SIZE=${TARGET_SWAP_SIZE:-2G}

USE_FLAGS="${USE_FLAGS:--systemd -X -gtk -gnome -kde -mysql -mariadb syslog openssl}"
# If you are in a hurry, you can remove -uD, this wil not update related packages, note --quiet-build will then be ---quiet-build with triple dash
EMERGE_ARGS="${EMERGE_ARGS:---quiet-build}"

# Packages to install after stage3 (stage 4 and rsync wil not install these)
EMERGE_PACKAGES="${EMERGE_PACKAGES:-sys-apps/mlocate app-admin/rsyslog app-admin/logrotate sys-process/cronie net-misc/chrony net-misc/dhcpcd app-admin/sudo app-admin/superadduser app-portage/mirrorselect app-shells/bash-completion}"

# More custom packages 
EMERGE_PACKAGES="$EMERGE_PACKAGES net-analyzer/net-snmp net-analyzer/munin" 

EMERGE_MAKEPATH=/etc/portage/make.conf

# Services to add to rc-update (autostart on boot) after stage3 (stage 4 and rsync wil not add these)
RC_UPDATE="${RC_UPDATE:-sshd rsyslog cronie chronyd}"

ROOT_PASSWORD="${ROOT_PASSWORD:-pass123}"
ROOT_SSH_PUBLIC_KEY="${ROOT_SSH_PUBLIC_KEY:-}"

CUSTOM_USER=${CUSTOM_USER:-MYUSERNAME}
CUSTOMUSER_PASSWORD="${CUSTOMUSER_PASSWORD:-pass123}"
CUSTOMUSER_SSH_PUBLIC_KEY="${CUSTOMUSER_SSH_PUBLIC_KEY:-}"
REQUIRED_PACKAGES="wget ntp"

GENTOO_STAGE3=$GENTOO_ARCH-$INIT
GRUB_PLATFORMS=${GRUB_PLATFORMS:-pc}

export CYAN='\033[0;36m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'

echo -e "${CYAN}### Starting installation, output is in install-log.txt ${NC}"
echo -e "${CYAN}### Checking prerequisites...${NC}"
for pkg in $REQUIRED_PACKAGES; do
  if ! command -v $pkg > /dev/null; then
    echo -e "${YELLOW}### $pkg not found, trying to install...${NC}"
    if command -v pacman > /dev/null; then 
      if [ ! "$(uname -n)" = "sysresue" ]; then
        pacman -Sy $pkg >> install-log.txt
      fi
    elif command -v apt-get > /dev/null; then apt-get update && apt-get install -y $pkg >> install-log.txt
    # elif command -v emerge > /dev/null; then emerge --quiet-build $pkg >> install-log.txt # gentoo livecd does not have emerge
    else
      echo -e "${RED}### No known package manager found, cannot install $pkg ${NC}"
      echo -e "${RED}### Please install $pkg manually and run the script again if the script fails ${NC}"
    fi
  fi
done

echo -e "${CYAN}### Setting time...${NC}"
if systemctl --all --type service | awk '$1 ~ '"/ntpd/" >/dev/null;then
    systemctl restart ntpd
else
    echo "${YELLOW}### Service ntpd does NOT exist, install might fail due to possible time issues"
fi

echo -e "${CYAN}### Checking if partitions already mounted and unmounting them...${NC}"
mount | grep '/mnt/gentoo/' | awk '{print $3}' | while read -r mountpoint; do
  echo -e "Unmounting $mountpoint..."
  umount "$mountpoint"
done
mount | grep "${TARGET_DISK}" | awk '{print $3}' | while read -r mountpoint; do
  umount "$mountpoint"
done
swapon --show=NAME | grep "${TARGET_DISK}" | while read -r swappart; do
  swapoff "$swappart"
done

echo -e "${CYAN}### Deleting old and creating new partitions...${NC}"
echo -e "${CYAN}### If the script stops now, just start it again, it's a bug somewhere...${NC}"

dd if=/dev/zero of=${TARGET_DISK} bs=512 count=1 >> install-log.txt 2>/dev/null
echo -e "o\nw" | fdisk ${TARGET_DISK} >> install-log.txt 2>/dev/null
sfdisk -q ${TARGET_DISK} << sfdisk >> install-log.txt 2>/dev/null
size=$TARGET_BOOT_SIZE,bootable
size=$TARGET_SWAP_SIZE
;
sfdisk

echo -e "${CYAN}### Formatting partitions...${NC}"
yes | mkfs.ext4 ${TARGET_DISK}1 >> install-log.txt 2>/dev/null
yes | mkswap ${TARGET_DISK}2 >> install-log.txt 2>/dev/null
yes | mkfs.ext4 ${TARGET_DISK}3 >> install-log.txt 2>/dev/null

echo -e "${CYAN}### Labeling partitions...${NC}"
e2label ${TARGET_DISK}1 boot
swaplabel ${TARGET_DISK}2 -L swap
e2label ${TARGET_DISK}3 root

echo -e "${CYAN}### Mounting partitions..."
mkdir -p /mnt/gentoo
mount ${TARGET_DISK}3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount ${TARGET_DISK}1 /mnt/gentoo/boot
swapon ${TARGET_DISK}2

cd /mnt/gentoo

if [ "$STAGE" = "STAGE4" ]; then
  echo -e "${RED}### STAGE4 is not finished, sorry ${NC}"
  exit 1
  STAGE4_URL="$CUSTOM_MIRROR/releases/$GENTOO_ARCH/stage4-amd64-openrc-$STAGE4_VERSION.tar.xz"
  wget -q "$STAGE4_URL"
  tar xpf "$(basename "$STAGE4_URL")" --xattrs-include='*.*' --numeric-owner
  rm -f "$(basename "$STAGE4_URL")"

elif [ "$STAGE" = "RSYNC" ]; then
  echo -e "${RED}### RSYNC is not finished, sorry ${NC}"
  exit 1
  rsync -avAXHW --numeric-ids --info=progress2 \
    --exclude='/dev/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    --exclude='/lost+found/' \
    rsync://$RSYNC_HOST/ /mnt/gentoo/

elif [ "$STAGE" = "STAGE3" ]; then
  echo -e "${CYAN}### Installing stage3...${NC}"
  STAGE_MIRROR=$(echo $GENTOO_MIRROR | cut -d' ' -f1)
  STAGE3_PATH_URL="$STAGE_MIRROR/releases/$GENTOO_ARCH/autobuilds/latest-stage3-$GENTOO_STAGE3.txt"
  STAGE3_PATH=$(curl -s "$STAGE3_PATH_URL" | grep -v "^#" | grep -v "BEGIN PGP" | grep -v "END PGP" | cut -d" " -f1 | grep "tar.xz$")
  STAGE3_URL="$STAGE_MIRROR/releases/$GENTOO_ARCH/autobuilds/$STAGE3_PATH"
  wget -q "$STAGE3_URL"
  tar xpf "$(basename "$STAGE3_URL")" --xattrs-include='*.*' --numeric-owner
  rm -f "$(basename "$STAGE3_URL")"

  echo "# added by gentoo installer" >> /mnt/gentoo/etc/fstab 
  echo "LABEL=boot /boot ext4 noauto,noatime 1 2" >> /mnt/gentoo/etc/fstab 
  echo "LABEL=swap none  swap sw             0 0" >> /mnt/gentoo/etc/fstab 
  echo "LABEL=root /     ext4 noatime        0 1" >> /mnt/gentoo/etc/fstab 

  echo -e "${CYAN}### Mounting proc/sys/dev...${NC}"
  mount --types proc /proc /mnt/gentoo/proc
  mount --rbind /sys /mnt/gentoo/sys
  mount --rbind /dev /mnt/gentoo/dev
  mount --bind /run /mnt/gentoo/run
  # Later, check if variable is systemd 
  if [ "$INIT" = "systemd" ]; then
    mount --make-rslave /mnt/gentoo/sys
    mount --make-rslave /mnt/gentoo/dev
    mount --make-slave /mnt/gentoo/run
  fi

  echo -e "${CYAN}### Fixing possible LiveCD issues...${NC}"
  test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
  mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm
  chmod 1777 /dev/shm 
  if [ -d "/run/shm" ]; then chmod 1777 /run/shm ; fi

  echo -e "${CYAN}### Changing root...${NC}"
  cp /etc/resolv.conf /mnt/gentoo/etc/
  echo -e "${CYAN}### Entering chroot...${NC}"
  chroot /mnt/gentoo /bin/bash -s <<- EOF
  #!/bin/bash

  set -e

  CYAN=\$CYAN
  YELLOW=\$YELLOW
  RED=\$RED
  NC=\$NC

  echo -e "${CYAN}### Upading configuration...${NC}"
  env-update
  source /etc/profile

  echo -e "${CYAN}### Setting up portage...${NC}"
  mkdir -p /etc/portage/repos.conf
  cp -f /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf
  if [ -n "$RSYNC_MIRROR" ]; then
    sed -i "s|rsync.gentoo.org|$RSYNC_MIRROR|g" /etc/portage/repos.conf/gentoo.conf
  fi

  # Some says emerge-webrsync is not recommended to call directly
  # emerge-webrsync -q >> install-log.txt 2>/dev/null
  emerge --sync --quiet 
  echo "# Added by gentoo-quick-installer" >> $EMERGE_MAKEPATH
  echo "USE=\"$USE_FLAGS\"" >> $EMERGE_MAKEPATH
  # mirrorselect -i -o >> /etc/portage/make.conf
  echo "GENTOO_MIRRORS=\"$GENTOO_MIRROR\"" >> $EMERGE_MAKEPATH
  # required to allow for linux-firmware (required for binary kernel).
  echo "sys-kernel/installkernel dracut" >> /etc/portage/package.use/installkernel
  
  if echo "$EMERGE_PACKAGES" | grep -q "net-analyzer/munin"; then
    echo "net-analyzer/munin minimal -cgi" >> /etc/portage/package.use/munin
    echo "dev-lang/perl berkdb" >> /etc/portage/package.use/perl
  fi
  echo "ACCEPT_LICENSE=\"-* @FREE\"" >> $EMERGE_MAKEPATH
  echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" >> /etc/portage/package.license
  echo "MAKEOPTS=\"-j$(nproc)\"" >> $EMERGE_MAKEPATH
  echo "GRUB_PLATFORMS=\"$GRUB_PLATFORMS\"" >> $EMERGE_MAKEPATH


  if [ "$GENTOO_DISTCC" ]; then
    echo -e "${CYAN}### Installing and setting up distcc...${NC}"
    echo -e "${YELLOW}### If EMERGE_ARGS contains -uD this might take som time...${NC}"
    emerge $EMERGE_ARGS sys-devel/distcc >> install-log.txt 2>/dev/null
    sed -i '/MAKEOPTS/s/^/#/' /etc/portage/make.conf
    echo "MAKEOPTS=\"-j$GENTOO_DISTCC_NUM -l$(nproc)\"" >> $EMERGE_MAKEPATH
    echo "FEATURES=\"distcc\"" >> $EMERGE_MAKEPATH
    echo "$tmpmakeconf" >> $EMERGE_MAKEPATH
    for host in $GENTOO_DISTCC; do echo "$host" >> /etc/distcc/hosts ; done
    rc-update add distccd default
    distcc-config --set-hosts "localhost $GENTOO_DISTCC"
  fi

  echo -e "${CYAN}### Installing kernel, this might time some time!...${NC}"munin
  emerge $EMERGE_ARGS sys-kernel/linux-firmware sys-kernel/installkernel >> install-log.txt 2>/dev/null
  emerge $EMERGE_ARGS virtual/dist-kernel sys-kernel/gentoo-kernel-bin >> install-log.txt 2>/dev/null

  echo -e "${CYAN}### Installing bootloader..."
  emerge $EMERGE_ARGS grub >> install-log.txt 2>/dev/null

  echo "# Added by gentoo-quick-installer" >> /etc/default/grub
  echo "GRUB_CMDLINE_LINUX=net.ifnames=0" >> /etc/default/grub
  echo "GRUB_DEFAULT=0" >> /etc/default/grub
  echo "GRUB_TIMEOUT=0" >> /etc/default/grub

  grub-install ${TARGET_DISK} >> install-log.txt 2>/dev/null
  grub-mkconfig -o /boot/grub/grub.cfg >> install-log.txt 2>/dev/null

  echo -e "${CYAN}### Configuring network...${NC}"
  sed -i "s/hostname=\".*\"/hostname=\"${HOSTNAME}\"/" /etc/conf.d/hostname
  ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
  rc-update add net.eth0 default

  if [ -n "$EMERGE_PACKAGES" ]; then
    echo -e "${CYAN}### Installing additional packages this might take some time...${NC}"
    for p in $EMERGE_PACKAGES; do
      echo -e "${CYAN}### Installing: \$p ${NC}"
      emerge $EMERGE_ARGS \$p >> install-log.txt 2>/dev/null
    done 
    emerge $EMERGE_ARGS $EMERGE_PACKAGES >> install-log.txt 2>/dev/null
  fi

  if [ -n "$RC_UPDATE" ]; then
    echo -e "${CYAN}### Adding \"$RC_UPDATE\" to rc-update...${NC}"
    for s in $RC_UPDATE; do
      rc-update add \$s default
    done 
  fi

  echo -e "${CYAN}### Configuring users...${NC}"
  if [ -z "$ROOT_PASSWORD" ]; then
    echo -e "${CYAN}### Removing root password...${NC}"
    passwd -d -l root
  else
    echo -e "${CYAN}### Setting root password...${NC}"
    echo "root:$ROOT_PASSWORD" | chpasswd >> install-log.txt
  fi

  if [ -n "$ROOT_SSH_PUBLIC_KEY" ]; then
    echo -e "${CYAN}### Setting root SSH Public key...${NC}"
    mkdir /root/.ssh
    echo -e "# Added by gentoo-quick-installer" > /root/.ssh/authorized_keys
    echo -e "$ROOT_SSH_PUBLIC_KEY" >> /root/.ssh/authorized_keys
    chmod 750 /root/.ssh
    chmod 640 /root/.ssh/authorized_keys
  fi

  if [ -n "$CUSTOM_USER" ] && [ -n "$CUSTOMUSER_PASSWORD" ]; then
    echo -e "${CYAN}### Adding custom user and setting password...${NC}"
    useradd -m -G users -s /bin/bash $CUSTOM_USER
    gpasswd -a $CUSTOM_USER wheel
    echo -e "$CUSTOM_USER:$CUSTOMUSER_PASSWORD" | chpasswd >> install-log.txt
    if command -v sudo > /dev/null; then 
      mkdir /etc/sudoers.d/
      echo -e "$CUSTOM_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$CUSTOM_USER
    fi
    if [ -n "$CUSTOMUSER_SSH_PUBLIC_KEY" ]; then
      echo -e "${CYAN}### Setting custom user SSH Public key...${NC}"
      mkdir /home/$CUSTOM_USER/.ssh
      echo -e "# Added by gentoo-quick-installer" > /home/$CUSTOM_USER/.ssh/authorized_keys
      echo -e "$CUSTOMUSER_SSH_PUBLIC_KEY" >> /home/$CUSTOM_USER/.ssh/authorized_keys
      chown -R $CUSTOM_USER:users /home/$CUSTOM_USER/.ssh
      chmod 750 /home/$CUSTOM_USER/.ssh
      chmod 640 /home/$CUSTOM_USER/.ssh/authorized_keys
    fi
  else
    echo -e "${CYAN}### Custom user not set, allowing root to login to ssh...${NC}"
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  fi
EOF
else
  echo -e "${RED}### Unsupported stage: $STAGE${NC}"
  exit 1
fi

echo -e "${GREEN}### Finshed, time to reboot...${NC}"
echo -e "${GREEN}### Password for root and custom_user (if set) is in the scriptfile if you didnt set it...${NC}"
