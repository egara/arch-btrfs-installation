# Arch installation on a BTRFS root filesystem
This is a cheatsheet with all the instructions to perform an installation of Arch Linux using BTRFS filesystem in /

[TOC]

## Laptop model ##
The installation has been done on a [Mountain Onyx](https://www.mountain.es/portatiles/onyx) laptop.

- **Screen**: 15,6" Full HD IPS Mate
- **CPU**: Intel® Core™ i7 6700HQ - 4C/8T
- **RAM**: 8GB DDR3L 1600 SODIMM
- **Hard Disk**: SSD 240GB M.2 550MB/s
- **GPU**: Nvidia GTX 960M 2GB GDDR5
- **UEFI**

## First steps ##
I have been following [Arch Wiki Beginner's Guide](https://wiki.archlinux.org/index.php/beginners'_guide). Arch ISO booted in UEFI mode using **systemd-boot**. It was configured a wired connection too.

## Partitioning ##
This is the selected layout for the UEFI/GPT system:

| Mount point | Partition | Partition type      | Bootable flag | Size   |
|-------------|-----------|---------------------|---------------|--------|
| /boot       | /dev/sda1 | EFI System Partition| Yes           | 512 MiB|
| [SWAP]      | /dev/sda2 | Linux swap          | No            | 16 GiB |
| /           | /dev/sda3 | Linux (BTRFS)       | No            | 30 GiB |
| /home       | /dev/sda4 | Linux (EXT4)        | No            | 192 GiB|

After creating the partitions, it was necessary to format them. Again, I followed the guide without a problem.

**IMPORTANT**: I used **-L** option with *mkfs* command in order to create a label for **/** (arch) and **/home** (home) partitions. It is important because fstab and the file needed to set up systemd-boot are configured to point those labels.

## BTRFS layout ##
The only partition formated with BTRFS was /dev/sda3, which contains the whole root system. BTRFS was selected to enable snapshots support in order to avoid any possible problem with Arch updates. Sometimes, I have experimented that certain critical package updates can break the system. If it occurs, it is a good idea to have some snapshot to rollback the entire root filesystem. tmp subvolume has been created in order to avoid the inclusion of temporal files within the snapshots of rootvol. tmp snapshots never will be created, because all the files stored within tmp are temporal. This is the layout defined:

```
sda3 (Volume)
|
|
- _active (Subvolume)
|    |
|    - rootvol (Subvolume - It will be the current /)
|    |
|    - tmp (Subvolume - It will be the current /tmp)
|
|
- _snapshots (Subvolume -  It will contain all the snapshots which are subvolumes too)
```
And these are the commands:

```
mkfs.btrfs -L arch /dev/sda3
mount /dev/sda3 /mnt
cd /mnt
btrfs subvolume create _active
btrfs subvolume create _active/rootvol
btrfs subvolume create _active/tmp
btrfs subvolume create _snapshots
```

Next, mount all the partitions (/boot included) in order to start the installation:

```
cd
umount /mnt
mount -o subvol=_active/rootvol /dev/sda3 /mnt
mkdir /mnt/{home,tmp,boot}
mount -o subvol=_active/tmp /dev/sda3 /mnt/tmp
mount /dev/sda1 /mnt/boot
mount /dev/sda4 /mnt/home
```

## Installing Arch Linux ##
Proceed with installing Arch Linux (Installation section within Beginner's guide).

## Fstab ##
After executing *genfstab -U /mnt >> /mnt/etc/fstab* to generate fstab file using **UUIDs** for the partitions, I edited fstab and this is the result (please note that for those partitions which have a label defined, this label has been used)

```
#
# /etc/fstab: static file system information
#
# <file system> <dir>   <type>  <options>       <dump>  <pass>
# /dev/sda3
LABEL=arch      /               btrfs           rw,relatime,compress=lzo,ssd,discard,autodefrag,space_cache,subvol=/_active/rootvol     0 0

# /dev/sda1
UUID=C679-F6A0          /boot           vfat            rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro    0 2

# /dev/sda3
LABEL=arch      /tmp            btrfs           rw,relatime,compress=lzo,ssd,discard,autodefrag,space_cache,subvol=/_active/tmp 0 0

# /dev/sda4
LABEL=home       /home           ext4            rw,relatime,data=ordered        0 2

# /dev/sda2
UUID=04293b56-e2f9-4d3b-aded-6baad666d5bb       none            swap            defaults        0 0

# /dev/sda3 LABEL=arch volume
LABEL=arch      /mnt/defvol             btrfs           rw,relatime,compress=lzo,ssd,discard,autodefrag,space_cache     0 0

```

## Mkinitcpio ##
In order to enable BTRFS on initramfs image, I added **btrfs** on HOOK inside **/etc/mkinitcpio.conf**. Then, it was necessary to execute **mkinitcpio -p linux** again.

## Bootloader ##
Because this is a UEFI laptop, [systemd-boot](https://wiki.archlinux.org/index.php/Systemd-boot) was used as a **bootloader**. First, it was necessary to install systemd-boot. /boot partition (/dev/sda1) was previously mounted, so it was only needed to execute **bootctl install**.
Then, I edited **/boot/loader/loader.conf**. This is the final content of this file:

```
timeout 3
default arch-btrfs
editor 0
```

Then, I installed **intel-ucode** package because I have an Intel CPU as beginners guide says.

Please, also note that **arch-btrfs** (above configuration) is the file created within **/boot/loader/entries** and its name is **arch-btrfs.conf**. This is the boot entry that we need to see Arch Linux option when the laptop boots, and the content of the file is:

```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=LABEL=arch rw rootflags=subvol=_active/rootvol
```

The line **initrd  /intel-ucode.img** enables Intel microcode updates (installed with intel-ucode package)

Please note that the line **options root=LABEL=arch rw rootflags=subvol=_active/rootvol** assumes that root partition is installed in the labeled as arch, so here it is no necessary to use PUUID, UUID or the name of the partition, only the label (using LABEL variable).

## Additional packages installed ##
A bunch of useful packages has been installed too: [tlp](https://wiki.archlinux.org/index.php/TLP) for energy saving and advanced power management, [reflector](https://wiki.archlinux.org/index.php/Reflector) for optimizing Arch mirrors repositories, [yaourt](http://www.ostechnix.com/install-yaourt-arch-linux/) for compiling and installing packages easily from AUR repository, [snapd](https://wiki.archlinux.org/index.php/Snapd) to install snap packages, [btrfs-progs](https://wiki.archlinux.org/index.php/Btrfs) to manage BTRFS filesystem.

## Finish the steps in the Wiki ##
And reboot!!

## Automated snapshots and system updates ##
A very simple script has been created called **upgrade-system.sh** and stored within **/usr/bin/upgrade-system.sh** for system upgrades. Before starting the installation of the packages updated, the script creates a new snapshot. Then, pacman, yaourt and snapd are launched to upgrade the system. If something went wrong, you can restore the root filesystem using the last snapshot created. This script can be found [here](https://github.com/egara/arch-btrfs-installation/blob/master/files/upgrade-system.sh)

## Configuration files ##
In this [folder](https://github.com/egara/arch-btrfs-installation/tree/master/files) you can find all the configuration files edited or created during the installation process.