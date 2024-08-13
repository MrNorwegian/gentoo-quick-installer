# gentoo-quick-installer

## FYI

This script was built only to learn bash and testing Gentoo, it's alot of bugs and unfinished stuff, it was fun making this but i'm not going to finish this since it was just a vacation project (got boored)

## About

This is a quick installer script that can be used to install1 amd64 Gentoo Linux quickly and easy.

Script has been tested with using systemrescuecd and archlinux live cd's:
- Proxmox VM 
- Lenovo L480 
- HP 430

You might be able to install gentoo with gentoo livecd, just adjust time before running this script

Many thanks to Original author Artem Butusov for a good base script that started alot of ideas

Read more: http://www.artembutusov.com/gentoo-linux-quick-installer-script/

# How to use method 1:

- Edit variables in the script, then

- sh gentoo-quick-installer.sh

* NOTE: Variables looks like this: HOSTNAME=${HOSTNAME:-gentoo}
* This sets gentoo as hostname, HOSTNAME=${HOSTNAME:-} This sets nothing if you are not using method 2 or 3 (HOSTNAME=gentoo sh gentoo-quick-installer.sh)


# How to use method 2: (Not tested)
- export ROOT_PASSWORD=SECRETPASSWORD

- export CUSTOM_USER=YOURUSERNAME

- export CUSTOMUSER_PASSWORD=SECRETPASSWORD

- export TARGET_DISK=/dev/vda

- sh gentoo-quick-installer.sh

# How to use method 3: (Not tested)

- ROOT_PASSWORD=Gentoo123 ./gentoo-quick-installer.sh

- CUSTOM_USER=YOURUSERNAME CUSTOMUSER_PASSWORD=SECRETPASSWORD sh gentoo-quick-installer.sh

- TARGET_DISK=/dev/vda ROOT_PASSWORD=SECRETPASSWORD sh gentoo-quick-installer.sh

# Other options:
- SSH_PUBLIC_KEY="...." - ssh public key, contents of `cat ~/.ssh/id_rsa.pub` for example

- ROOT_PASSWORD=pass123

- TARGET_DISK=/dev/sda

/dev/vda is standard for most Virtual Machines.

/dev/nvme0n1 is standard for NVME drives.

/dev/mmcblk0 is standard for most eMMC and SD drives

- GENTOO_ARCH=amd64

amd64 is default

- INIT=openrc

openrc is default

systemd is a alternative for openrc

- STAGE=STAGE3

STAGE3 is default

STAGE4 is custom stage3, requires you to edit CUSTOM_MIRROR="http://....../gentoo"

- STAGE4_VERSION=latest
latest is default

stage4_version is part of the stage4 filename, look at this variable: $CUSTOM_MIRROR/releases/$GENTOO_ARCH/stage4-amd64-openrc-$STAGE4_VERSION.tar.xz"

- There is more variables to change, please tak a look in the top of the script

## Notes:

- This script does not work (Or tested) with Secure boot or UEFI. only Legacy BIOS.

## Copyright

- gentoo-quick-installer is licensed under the MIT.

- A copy of this license is included in the file LICENSE.txt
