#!/bin/bash -e

. shell-error
. shell-quote
. shell-args

PROG="${0##*/}"
PROG_VERSION='0.1.0'

SHORT_OPTIONS='h,v'
LONG_OPTIONS='help,version'

print_version()
{
	cat <<EOF
$PROG version $PROG_VERSION
Written by Anatoly Sinelnikov <tolya@darkmastersin.net>

Copyright (C) 2021 Anatoly Sinelnikov <tolya@darkmastersin.net>
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
EOF
	exit
}

show_help()
{
	cat <<EOF
$PROG - install multi image usb flash.

Usage: $PROG <storage-device> [<iso-image>...]

EOF
	exit
}

TEMP=`getopt -n $PROG -o "$SHORT_OPTIONS" -l "$LONG_OPTIONS" -- "$@"` ||
	show_usage
eval set -- "$TEMP"

while :; do
	case "$1" in
		--) shift; break
			;;
		-h|--help) show_help
			;;
		-v|--version) print_version
			;;
		*) fatal "Unrecognized option: $1"
			;;
	esac
	shift
done

if [ $# -lt 1 ]; then
	fatal "Storage device not defined."
fi

STORAGE_DEVICE="$1"; shift

is_disk() {
	if lsblk -o 'TYPE' -P "$1" 2>/dev/null | grep -q '^TYPE="disk"$'; then
		return 0
	fi
	return 1
}

is_usb() {
	if lsblk -o 'SUBSYSTEMS' -P "$1" 2>/dev/null | grep -q '^SUBSYSTEMS="block:scsi:usb:pci'; then
		return 0
	fi
	return 1
}

umount_all_partions()
{
	local dev mnt
	lsblk -o PATH,MOUNTPOINT -P "$1" | while read d m; do
		dev=$(echo "$d" | sed 's/PATH="\(.*\)"/\1/')
		mnt=$(echo "$m" | sed 's/MOUNTPOINT="\(.*\)"/\1/')
		if test -n "$mnt" && mountpoint -q "$mnt"; then
			umount -A "$dev"
		fi
	done
}

if ! is_disk "$STORAGE_DEVICE"; then
	fatal "'$STORAGE_DEVICE' is not storage device (block device disk)."
fi

if ! is_usb "$STORAGE_DEVICE"; then
	fatal "'$STORAGE_DEVICE' is not usb storage device (block device subsystem is not 'block:scsi:usb:pci')."
fi

tmpdir=
mntdir=
cleanup_handler()
{
	trap - EXIT
	if mountpoint -q "$mntdir"; then
		umount -A "$mntdir"
	fi
	if [ -n "$tmpdir" ]; then
		rm -rf -- "$tmpdir"
	fi
	exit "$@"
}

exit_handler()
{
	cleanup_handler $?
}

signal_handler()
{
	cleanup_handler 1
}

trap exit_handler EXIT
trap signal_handler HUP PIPE INT QUIT TERM

tmpdir="$(mktemp -dt "$PROG.XXXXXXXX")"
mntdir="$tmpdir/mnt"
mkdir "$mntdir"

BOOTPART="${STORAGE_DEVICE}1"

install_grub()
{
	umount_all_partions "$STORAGE_DEVICE"
	echo -e "o\nn\np\n1\n\n+256M\nt\nb\nw\n" | fdisk -W always "$STORAGE_DEVICE"
	mkfs.fat "$BOOTPART"
	mount "$BOOTPART" "$mntdir"
	grub-install --boot-directory="$mntdir" "$STORAGE_DEVICE"
}

install_grub

for iso in "$@"; do
	echo -n "file: '$iso' "
	[ -f "$iso" ] && echo "is file" || echo "is not file"
done
