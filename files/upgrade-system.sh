#!/bin/bash
if hash btrfs 2>/dev/null; then
	echo "Creating a read-only snapshot of the system. Please wait..."
	sudo btrfs subvolume snapshot -r /mnt/defvol/_active/rootvol/ /mnt/defvol/_snapshots/root-$(date "+%F")
else
    echo "btrfs-progs not installed. Please, install it."
fi

echo "Upgrading the system. Please wait..."
sudo pacman -Syu --noconfirm

if hash yaourt 2>/dev/null; then
	echo "Upgrading the system from AUR. Please wait..."
	yaourt -Syua --noconfirm
else
    echo "yaourt not installed. Please, install it."
fi

if hash yaourt 2>/dev/null; then
	echo "Upgrading snap packages. Please wait..."
	sudo snap refresh
else
    echo "snapd not installed. Please, install it."
fi
