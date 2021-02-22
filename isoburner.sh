#!/bin/bash

is_disk() {

if lsblk -o TYPE -P "$1" 2>/dev/null | grep -q '^TYPE="disk"$'; then
	echo it is disk
else
	echo it is not disk
fi

}

for i in /dev/sda /dev/sdb /dev/sdc /dev/sdd; do
	echo -n "$i: "
	is_disk $i
done

