#!/bin/bash

# NCB_NCDIR: (optional) Directory of nextcloud snap, defaults to /var/snap/nextcloud.
# NCB_VG: (optional) LVM volume group to take a snapshot of for the backup. No snapshot if empty.
# NCB_LV: (optional, mandatory if NCB_VG is set) LVM logical volume  to take a snapshot of for the backup.
# NCB_SMNT: (optional) where to mount to the snapshot. Defaults to empty if no snapshot, defaults to /backup with snapshots.
# NCB_SRC: (optional) directory to backup. Defaults to $NCB_SMNT/$NCB_NCDIR
# NCB_SLV: (optional) name of snapshot LV. Defaults to "backup".
# NCB_DUPLICITY_DEST (optional): duplicity upload target
# NCB_DUPLICITY_SSH_OPTIONS (optional): value of duplicity "--ssh-options" argument

set -e
set -x

bin_exists () {
    which "$1" &> /dev/null && return
    echo "$1" not found
    false
}

export PATH=$PATH:/snap/bin

bin_exists nextcloud.occ
bin_exists nextcloud.mysqldump
bin_exists lvcreate
bin_exists duplicity

NCB_NCDIR="${NCB_NCDIR:-/var/snap/nextcloud}"

if [[ ! -d "$NCB_NCDIR" ]]; then
    echo "Directory NCB_NCDIR=$NCB_NCDIR does not exist" >&2
    exit 1
fi

if [[ -z "$NCB_DUPLICITY_DEST" ]]; then
    echo "NCB_DUPLICITY_DEST is not set" >&2
    exit 1
fi


if [[ -n "$NCB_VG" ]]; then
    if [[ -z "$NCB_LV" ]]; then
        echo "NCB_LV must be set if NCB_VG is set" >&2
        exit 1
    fi
    # LVM snapshot needed
    NCB_SMNT="${NCB_LVMNT:-/backup}"
    NCB_SLV="${NCB_SLV:-backup}"
else
    NCB_SMNT=""
fi

NCB_SRC="${NCB_SRC:-$NCB_LVMNT/$NCB_NCDIR}"

if [[ -n "$NCB_LV" ]]; then
    echo "Snapshotting $NCB_VG/$NCB_LV to $NCB_SLV, mounting into $NCB_SMNT"
fi

lvpath="/dev/$NCB_VG/$NCB_LV"
slvpath="/dev/$NCB_VG/$NCB_SLV"
dbbf="$NCB_NCDIR/db-backup.sql"

[[ -n "$NCB_SMNT" ]] && lvremove -f "$slvpath" || true
rm -f "$dbbf" || true

nextcloud.occ maintenance:mode --on

echo "Dumping database"

nextcloud.mysqldump > "$dbbf"

if [[ -n "$NCB_SMNT" ]]; then
    trap "umount $NCB_SMNT; lvremove -f $slvpath" EXIT

    echo "Creating snapshot volume"

    lvcreate -l 100%FREE -s "$lvpath" -n "$NCB_SLV"

    # We have everything in the snapshot so we can re-enable nextcloud
    nextcloud.occ maintenance:mode --off
    mkdir -p "$NCB_SMNT"
    mount -o ro "$slvpath" "$NCB_SMNT"
fi

echo "Running duplicity"

if [[ -n "$NCB_DUPLICITY_SSH_OPTIONS" ]]; then
    duplicity --ssh-options "$NCB_DUPLICITY_SSH_OPTIONS" "$NCB_SRC" "$NCB_DUPLICITY_DEST"
else
    duplicity "$NCB_SRC" "$NCB_DUPLICITY_DEST"
fi

[[ -z "$NCB_SMNT" ]] && nextcloud.occ maintenance:mode --off

exit 0
