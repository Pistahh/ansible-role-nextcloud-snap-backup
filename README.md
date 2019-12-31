# pistahh.nextcloud-snap-backup

Ansible role to set up local NextCloud installation backups using duplicity.
It copies a backup script to the NextCloud host and sets up systemd service/timer to run it periodically.

The scripts backs up all the directory content (incl. binaries, etc.), not just the "data".

The script expects binaries provided by the nextcloud snap (e.g. `nextcloud.occ` ) to be available.

## Modes of operation

### LVM snapshot mode

This mode minimizes downtime (maintenance mode), but it requires LVM and enough free space in the LVM volume group (VG) for a snapshot.

This mode is used if the variables `ncbackup_lvm_vg` and `ncbackup_lvm_lv` are set.

1. puts the instance into maintenance mode
2. dumps the database
3. creates an LVM snapshot and mounts it
4. turns off maintenance mode
5. backs up the snapshot
6. unmounts and removes the snapshot

### Non-LVM mode

In this mode the instance is in maintenance mode (i.e. "down") as long as the backup is taken, given the amount of data stored in the instance this can take quite long. Not recommended.

This mode

1. puts the instance into maintenance mode
2. dumps the database
3. backs up the snapshot
4. turns off maintenance mode

## Restoring the backup

This is not automated.

1. Use duplicity to restore the directory structure with the content
2. Restore the database from the file `db-backup.sql` (found in the restored content)

## Variables

* `ncbackup_lvm_vg`: name of LVM volume group to snapshot. Optional.
* `ncbackup_lvm_lv`: name of LVM logical volume to snapshot. Optional.
* `ncbackup_duplicity_ssh_options`: options for duplicity to pass to the ssh client
* `ncbackup_duplicity_dest`: duplicity backup target url (where the backups should go)
* `ncbackup_duplicity_passphrase`: (GPG) pasphrase duplicity uses for the backups.
* `ncbackup_duplicity_ncdir`: Directory of nextcloud installation. Optional, defaults to `/var/snap/nextcloud`.
* `ncbackup_timer`: when to run the backups (systemd "OnCalendar" format)

## Example
```
ncbackup_lvm_vg: ubuntu-vg
ncbackup_lvm_lv: ubuntu-lv
ncbackup_duplicity_ssh_options: "-oIdentityFile=/root/.ssh/backup -oUser=ncbackup"
ncbackup_duplicity_dest: "rsync://mybackupserver/mnt/backup"
ncbackup_duplicity_passphrase: "s3cr3tPutMe1nThe4nsibleVault"
ncbackup_timer: '*-*-* 02:00:00'
```