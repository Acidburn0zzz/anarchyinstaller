#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="anarchy"
iso_label="ANARCHY130"
iso_publisher="Anarchy Installer <https://anarchyinstaller.org>"
iso_application="Anarchy Installer"
iso_version="1.3.0"
install_dir="anarchy"
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
