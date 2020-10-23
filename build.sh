#!/bin/sh

ISO_VERSION="1.3.0-beta2"
REPO_DIR="$(pwd)"
BUILD_DIR="${REPO_DIR}"/build
OUT_DIR="${REPO_DIR}"/out
ARCHISO_DIR=/usr/share/archiso/configs/releng

# Check root permission
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "$0 needs to be run with root permissions"
        exit
    fi
}

# Check if dependencies are installed
check_deps() {
    echo "Checking dependencies"

    if ! pacman -Qi archiso > /dev/null 2>&1; then
        echo "'archiso' is not installed, but is required by $0, do you want to install it?"
        echo "Install [Y/n]: "
        read -r ans

        case "${ans}" in
            n|N|no|NO|No|nO) echo "Not installing 'archiso', exiting" ; exit ;;
            *) sudo pacman -Sy archiso ;;
        esac
    fi

    if ! pacman -Qi mkinitcpio-archiso > /dev/null 2>&1; then
        echo "'mkinitcpio-archiso' is not installed, but is required by $0, do you want to install it?"
        echo "Install [Y/n]: "
        read -r ans

        case "${ans}" in
            n|N|no|NO|No|nO) echo "Not installing 'mkinitcpio-archiso', exiting" ; exit ;;
            *) sudo pacman -Sy mkarchiso-archiso ;;
        esac
    fi
}

prepare_build_dir() {
    echo "Preparing build directory"

    # Create temporary directory if not exists
    [ ! -d "${BUILD_DIR}" ] && mkdir "${BUILD_DIR}"

    # Copy archiso files to tmp dir
    sudo cp -r "${ARCHISO_DIR}"/* "${BUILD_DIR}"/

    # Copy anarchy files to tmp dir
    sudo cp -Tr "$(pwd)/src/airootfs/root" "${BUILD_DIR}/airootfs/root"
    sudo cp -Tr "$(pwd)/src/airootfs/usr" "${BUILD_DIR}/airootfs/usr"
    sudo cp -Tr "$(pwd)/src/airootfs/etc" "${BUILD_DIR}/airootfs/etc"
    sudo cp -Tr "$(pwd)/src/syslinux" "${BUILD_DIR}/syslinux"
    sudo cp -Tr "$(pwd)/src/isolinux" "${BUILD_DIR}/isolinux"
    sudo cp -Tr "$(pwd)/src/efiboot" "${BUILD_DIR}/efiboot"

    # Remove motd file
    sudo rm "${BUILD_DIR}/airootfs/etc/motd"

    # Add anarchy packages
    cat "$(pwd)/anarchy-packages.x86_64" >> "${BUILD_DIR}/packages.x86_64"
}

ssh_config() {
    echo "Adding SSH config"

    # Check optional configuration file for SSH connection
    if [ -f autoconnect.sh ]; then
        # shellcheck disable=SC1091
        . autoconnect.sh

        # Copy PUBLIC_KEY to authorized_keys
        if [ ! -d airootfs/etc/skel/.ssh ]; then
            mkdir -p airootfs/etc/skel/.ssh
        fi
        cp "${PUBLIC_KEY}" airootfs/etc/skel/.ssh/authorized_keys
        chmod 700 airootfs/etc/skel/.ssh
        chmod 600 airootfs/etc/skel/.ssh/authorized_keys
    fi
}

geniso() {
    echo "Generating iso"

    mkarchiso -v \
            -P "Anarchy Installer <https://anarchyinstaller.org>" \
            -A "Anarchy Installer" \
            -o "${OUT_DIR}" \
            -L "ANARCHY" \
            -c zstd \
            "${BUILD_DIR}" || exit
}

cleanup() {
    echo "Cleaning up"
    sudo chown -R "${USER}":"${USER}" "${OUT_DIR}" || exit
    sudo rm -rf "${BUILD_DIR}" || exit
}

checksum_gen() {
    echo "Generating checksum"

    cd "${OUT_DIR}" || exit
    filename="anarchy-${ISO_VERSION}-x86_64.iso"

    if [ ! -f  "${filename}" ]; then
        echo "Mising file ${filename}"
        exit
    fi

    sha512sum --tag "${filename}" > "${filename}".sha512sum || exit
    echo "Created checksum file ${filename}.sha512sum"
}

upload_iso() {
    echo "Uploading iso"

    cd "${OUT_DIR}" || exit
    filename="anarchy-${ISO_VERSION}-x86_64.iso"
    checksum="${filename}.sha512sum"

    if [ ! -f "${filename}" ] || [ ! -f "${checksum}" ]; then
        echo "${filename} or ${checksum} missing, can't upload!"
        exit
    fi

    echo "Enter your osdn.net username: "
    read -r username

    echo "Is this a testing or release iso?"
    echo "[T/r]: "
    read -r reltype

    case "${reltype}" in
        r|R|rel|Rel|release|Release|RELEASE) dir='' ;;
        *) dir='testing/' ;;
    esac

    if ! pacman -Qi rsync > /dev/null 2>&1; then
        echo "'rsync' is not installed, do you want to install it?"
        echo "Install [Y/n]: "
        read -r ans

        case "${ans}" in
            n|N|no|NO|No|nO) sudo pacman -Sy rsync ;;
            *) echo "Not installing 'rsync', exiting" ; exit ;;
        esac
    fi

    rsync "${OUT_DIR}/${filename} ${OUT_DIR}/${checksum}" \
            "${username}"@storage.osdn.net:/storage/groups/a/an/anarchy/"${dir}"
}

main() {
    check_root
    check_deps
    prepare_build_dir
    ssh_config
    geniso
    cleanup
    checksum_gen
}

if [ $# -eq 0 ]; then
	main
else
    case "$1" in
        -u) # build and upload
            main
            upload_iso
            ;;
        -o) upload_iso ;; # only upload
        *) echo "Usage: $0 [-u|-o]" ; exit ;;
    esac
fi
