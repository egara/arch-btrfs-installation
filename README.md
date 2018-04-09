# Arch installation on a BTRFS root filesystem
This is a cheatsheet with all the instructions to perform an installation of Arch Linux using BTRFS filesystem in /

[TOC]

## Laptop model ##
The installation has been done on a [Mountain Onyx](https://www.mountain.es/portatiles/onyx) laptop.

- **Screen**: 15,6" Full HD IPS Mate
- **CPU**: Intel® Core™ i7 6700HQ - 4C/8T
- **RAM**: 8GB DDR3L 1600 SODIMM
- **Hard Disk**: SSD 240GB M.2 550MB/s
- **GPU**: Nvidia GTX 960M 2GB GDDR5 + Intel i915 (Skylake)
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
In order to enable BTRFS on initramfs image, I added **btrfs** on HOOK inside **/etc/mkinitcpio.conf**. Then, it was necessary to execute **mkinitcpio -p linux** again. If you install linux-lts kernel (Long Term Support), you will have to execute **mkinitcpio -p linux-lts**

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

## Re-installing the system ##
The previous way didn't work as I expected. Because of /boot partition is independent, if you want to rollback to a previous snapshot with a different kernel installed there is a problem. I don't snapshot /boot, so there it is always the images generated for the last kernel installed. This is a problem! So I reinstalled the whole system disabling UEFI mode and enabling legacy BIOS. Then, I partitioned the system using only thre partitions: sda1 for / (inlcuidng boot partition), sda2 for swap and sda3 for home. sda1 is BTRFS, but because of the whole root system is stored there, now when I snapshot this partition, /boot is included and there is no problem with different kernel installations. I used GRUB as a boot loader.

## Graphics and Optimus installation ##
The laptop has two graphic cards: Integrated: **Intel i915** and discrete **NVIDIA GTX 960M**. Then, it is interesting to have optimus technology enabled and working fine. This way, NVIDIA graphics card will only be used when a game is executed, saving power and extending battery life. These are the steps followed to have this technology working on this hardware (it was a little tricky). 

++Note:++ For a stable installation, it is recommended a LTS system instead of a cutting edge one. Because of this, I installed **linux-lts** and **linux-lts-headers** instead of normal kernel and **nvidia-lts** and **bbswitch-lts** from the repository.

For the graphics cards installation and Optimius:

- Install video graphic drivers: [Intel](https://wiki.archlinux.org/index.php/intel_graphics#Installation) including vulkan support and [bumblebee with NVIDIA](https://wiki.archlinux.org/index.php/bumblebee#Installing_Bumblebee_with_Intel.2FNVIDIA)

- Install [primus and lib32-primus](https://wiki.archlinux.org/index.php/bumblebee#Primusrun)
- We will add three [kernel boot parameters in GRUB](https://wiki.archlinux.org/index.php/Kernel_parameters#GRUB). Edit **/etc/default/grub** and change **GRUB_CMDLINE_LINUX_DEFAULT**. The line should be like this (I have removed **quiet** in order to see all the details of the booting process and check that evrything is OK):

      GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_rc6=0 pcie_port_pm=off acpi_osi=\"!Windows 2015\""

  The three kernel boot parameters added are:

  - Kernel boot parameter for [Skylake i915 GPU](https://wiki.archlinux.org/index.php/intel_graphics#Skylake_support).
  - If you are using kernel 4.8 or higher, add kernel boot parameter **pcie_port_pm=off** as you can see [here](https://wiki.archlinux.org/index.php/NVIDIA/Troubleshooting#Modprobe_Error:_.22Could_not_insert_.27nvidia.27:_No_such_device.22_on_linux_.3E.3D4.8) for avoiding error **"Could not insert 'nvidia': No such device"**
  - Kernel boot parameter **acpi_osi=\"!Windows 2015\"** for avoiding the system freezes when we enable bumblebeed.service.

  Finally, execute **sudo grub-mkconfig -o /boot/grub/grub.cfg** in order to rebuild grub configuration with all these changes.
  
- Add modules **intel_agp** and **i915** (intel_agp must go always before i915) as you can see [here](https://wiki.archlinux.org/index.php/intel_graphics#Blank_screen_during_boot.2C_when_.22Loading_modules.22) within [mkinitcpio.conf](https://wiki.archlinux.org/index.php/Kernel_mode_setting#Early_KMS_start) in order to enable KMS during the initramfs stage. This will avoid a black screen and will prevent the system to freeze. Rebuild initramfs using **mkinitcpio -p linux** or **mkinitcpio -p linux-lts** depending on the kernel you have installed.

- Install **bbswitch** for graphic cards power management: **sudo pacman -S bbswitch** (if you are using linux-lts or custom kernel, **bbswitch-dkms** is recommended)

- For launching Steam games and use NVIDIA graphics card, open Steam --> Library --> right click on the game you want to launnch --> Set Launch Options -> Type: **optirun -b primus %command%**
- For launching wine games and use NVIDIA graphics card, launch the game with **env WINEPREFIX="/home/egarcia/.wine" /usr/bin/optirun -b primus wine C:\\windows\\command\\start.exe /Unix /home/egarcia/.wine/dosdevices/c:/users/Public/Escritorio/Hearthstone.lnk**. Another method is, for example to execute **Battle.net** with wine, execute de exe file using **optirun -b primus wine "C:\Program Files (x86)\Battle.net\Battle.net.exe"**

### Resources ##
[Antergos Wiki for Bumblebee, NVIDIA and Optimus](https://antergos.com/wiki/hardware/bumblebee-for-nvidia-optimus/)

## Bluetooth installation ##
Normally, bluetooth chipset (intel/ibt-11-5.sfi) should work out of the box, but there is a problem loading **btusb** kernel module. In order to make it work, it is necessary to create a script in **/usr/bin** called **start-bluetooth.sh** with this content:

```
#!/bin/bash
modprobe -r btusb
modprobe btusb
```

++Tip:++ If you want, you can create a desktop launcher and locate it within **~/.local/share/applications** with this content:

```
[Desktop Entry]
Comment[en_US]=
Comment=
Exec=gksudo /usr/bin/start-bluetooth.sh
GenericName[en_US]=
GenericName=
Icon=preferences-system-bluetooth
MimeType=
Name[en_US]=Bluetooth
Name=Bluetooth
Path=
StartupNotify=true
Terminal=false
TerminalOptions=
Type=Application
X-DBUS-ServiceName=
X-DBUS-StartupType=
X-KDE-SubstituteUID=false
X-KDE-Username=
```

## Problem with Docker and BTRFS ##
More than a problem is a caveat. If the main filesystem  for root is BTRFS, docker will use BTRFS storage driver (Docker selects the storage driver automatically depending on the system's configuration when it is installed) to create and manage all the docker images, layers and volumes. It is ok, but there is a problem with snapshots. Because **/var/lib/docker** is created to store all this stuff in a BTRFS subvolume which is into root subvolume, all this data won't be included within the snapshots. In order to allow all this data be part of the snapshots, we will change the storage driver used by Docker. It will be used **devicemapper**. Please, check out [this reference](https://docs.docker.com/engine/userguide/storagedriver/selectadriver/) in order to select the proper storage driver for you. You must know that depending on the filesystem you have for root, some of the storage drivers will not be allowed.

For using devicemapper:
- Install docker
- Create a file called **storage-driver.conf** within **/etc/systemd/system/docker.service.d/**. If the directory downs't exist, create the directory first.
- This is the content of **storage-driver.conf**
```
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --storage-driver=devicemapper
```

- Create **/var/lib/docker/** and disable CoW (copy on write for BTRFS):
```
sudo chattr +C /var/lib/docker
```

- Enable and start the service
```
sudo systemctl enable docker.service
sudo systemctl start docker.service
```

- Add your user to docker group in order to use docker command withou sudo superpowers!

## Pulseaudio high battery consuption ##
Using **Energy Information** application provided by KDE Plasma, I realized that pulseaudio daemon was eating the energy of my battery in a very strange way. Then I realized that it was a bug described [here](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/877560). To fix this bug, it is necessary to manually force power save for the audio codec:

- Before proceeding, in a terminal launch the following command:

      cat /sys/module/snd_hda_intel/parameters/power_save*

  if the result is different from:

      1
      Y

  then try the following commands

      echo 1 | sudo tee /sys/module/snd_hda_intel/parameters/power_save
      echo Y | sudo tee /sys/module/snd_hda_intel/parameters/power_save_controller
      pkill pulseaudio

- Log out and log in again to get pulseaudio restarted.

## Restructuring BTRFS Layout on Antergos or another distribution ##

- I have installed [Antergos](https://antergos.com/) (Arch-based distro easy to install and to go without too much configuration) on a PC (using BIOS legacy mode instead UEFI) that I needed to work inmediately. I used BTRFS too for the installation, but the problem is that you cannot choose the layout you want for your BTRFS volume. Instead, all the root system is installed directly in the top volume itself, but I want a more refined layout (the layout defined above) in order to manage all the snapshots in a more proper way. Because of that, I detailed all the steps I made in order to mmigrate my installation to a customize layout.
Once the system is installed, reboot and open a terminal to see the structure of the BTRFS volume for /:
```
sudo btrfs subvolume list /
cd /
```
Create all the subvolumes on / except rootvol subvolume:
```
sudo btrfs subvolume create _active
sudo btrfs subvolume create _active/tmp
sudo btrfs subvolume create _snapshots
```
Now, it is necessary to make a read-write snapshot of / into _active/rootvol
```
sudo btrfs subvolume snapshot / /_active/rootvol
```
Reboot the system using Archlinux LiveCD or Antergos LiveCD.
Once the system is booted, mount all the structure within /mnt using as root /_active/rootvol (in my case, / is in /dev/sda1 and /home is in /dev/sdb2):
```
mount -o subvol=/_active/rootvol /dev/sda1 /mnt
mount -o subvol=/_active/tmp /dev/sda1 /mnt/tmp
mount /dev/sdb2 /mnt/home
```
Chroot the new system:
```
arch-chroot /mnt /bin/bash
```
Add **btrfs** as HOOK within /etc/mkinitcpio.conf and rebuild images:
```
mkinitcpio -p linux
```
Create a new directory called **defvol** within /mnt
```
mkdir /mnt/defvol
```
Modify **fstab** to reflect the changes (remember to modify / entry and point it to /_active/rootvol. Add /tmp line too). It is interesting to add /mnt/defvol in order to mount the entire volume as it is described above too. Systemd sometimes creates /var/lib/machines subvolume so add it too. The fstab file should look like this:
```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
#
UUID=238a2358-8bf6-47a9-907f-47eaece88632 /home ext4 defaults,rw,relatime,data=ordered 0 0
UUID=ce5c80f2-9edd-42f6-b920-d8ae43ac461b / btrfs defaults,rw,noatime,compress=lzo,ssd,discard,space_cache,autodefrag,inode_cache,subvol=/_active/rootvol 0 0
UUID=ce5c80f2-9edd-42f6-b920-d8ae43ac461b /tmp btrfs defaults,rw,noatime,compress=lzo,ssd,discard,space_cache,autodefrag,inode_cache,subvol=/_active/tmp 0 0
UUID=ce5c80f2-9edd-42f6-b920-d8ae43ac461b /var/lib/machines btrfs defaults,rw,noatime,compress=lzo,ssd,discard,space_cache,autodefrag,inode_cache,subvol=/var/lib/machines 0 0
UUID=ce5c80f2-9edd-42f6-b920-d8ae43ac461b /mnt/defvol btrfs defaults,rw,noatime,compress=lzo,ssd,discard,space_cache,autodefrag,inode_cache,subvol=/ 0 0
UUID=4621e43f-3b86-4fa2-9d9e-823a564572f4 swap swap defaults 0 0
```
Reinstall GRUB (in my case, the PC was installed in BIOS legacy mode and GRUB is installed on /dev/sda):
```
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```
Exit chroot and unmount everything.
```
exit
umount /mnt -R
```
Reboot.
Once the system is booted, check if **/** is pointing to **/_active/rootvol**. If everything is working fine, all the files within the root of the volume can be deleted.
```
cd /mnt/defvol
sudo rm -rf b*
sudo rm -rf d*
sudo rm -rf e*
sudo rm -rf h*
sudo rm -rf l*
sudo rm -rf m*
sudo rm -rf o*
sudo rm -rf p*
sudo rm -rf r*
sudo rm -rf s*
sudo rm -rf t*
sudo rm -rf u*
```
At this point, only **_active**, **_snapshots** and **var** should exist within **/mnt/defvol**.
Go to **/mnt/defvol/_active/rootvol** and you can safely delete **_active** and **_snapshots**:
```
cd /mnt/defvol/_active/rootvol
sudo rm -rf _active
sudo rm -rf _snapshots
```
**DONE!!! :)**
This is the [original post](http://unix.stackexchange.com/questions/62802/move-a-linux-instalation-using-btrfs-on-the-default-subvolume-subvolid-0-to-an) from I got the inspiration to do this stuff.

## Do you want to contact me? ##
For more information, please check my [portfolio web page at https://egara.github.io](https://egara.github.io)
