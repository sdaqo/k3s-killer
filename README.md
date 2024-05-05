# k3s-killer
A little script to reduce CPU usage in truenas scale systems with kubernetes running.

Refer to this thread to know why this exists: https://www.truenas.com/community/threads/k3s-server-uses-10-cpu-for-no-reason.91326/

## Install & Usage

### Install for cobia versions (>= TrueNAS-SCALE-23) 
1. Git clone this repo
3. Run: `./k3s-kill.sh install`
4. (Optional) Run: `./k3s-kill.sh cron` to set up your cron jobs (e.g. for Nextclolud)
5. Run: `./k3s-kill.sh kill` to kill the k3s server.

### Install for dragonfish versions (>= TrueNAS-SCALE-24)
1. Git clone this repo
2. Run: `sudo zfs list -r boot-pool/ROOT` and copy the name that ends in `/usr` and is preceded by the system version you are running.
   
For example:
```
admin@truenas[~/k3s-killer]$ sudo zfs list -r boot-pool/ROOT
NAME                                         USED  AVAIL  REFER  MOUNTPOINT
boot-pool/ROOT                              7.69G   425G    96K  none
boot-pool/ROOT/23.10.1                      2.72G   425G  2.71G  legacy
boot-pool/ROOT/23.10.2                      2.49G   425G  2.49G  legacy
boot-pool/ROOT/24.04.0                      2.48G   425G   164M  legacy
boot-pool/ROOT/24.04.0/audit                 612K   425G   612K  /audit
boot-pool/ROOT/24.04.0/conf                  140K   425G   140K  /conf
boot-pool/ROOT/24.04.0/data                  372K   425G   372K  /data
boot-pool/ROOT/24.04.0/etc                  7.84M   425G  6.88M  /etc
boot-pool/ROOT/24.04.0/home                 9.74M   425G  9.74M  /home
boot-pool/ROOT/24.04.0/mnt                    96K   425G    96K  /mnt
boot-pool/ROOT/24.04.0/opt                  74.2M   425G  74.1M  /opt
boot-pool/ROOT/24.04.0/root                 36.7M   425G  36.7M  /root
boot-pool/ROOT/24.04.0/usr                  2.12G   425G  2.12G  /usr  <--- This is the one we want!
boot-pool/ROOT/24.04.0/var                  76.1M   425G  32.5M  /var
boot-pool/ROOT/24.04.0/var/ca-certificates    96K   425G    96K  /var/local/ca-certificates
boot-pool/ROOT/24.04.0/var/log              42.8M   425G  42.8M  /var/log
boot-pool/ROOT/Initial-Install                 8K   425G  2.33G  /
```
3. Run: `sudo zfs set readonly=off your-value-here`.
   
For example (we take the value from above):
```
$ sudo zfs set readonly=off boot-pool/ROOT/24.04.0/usr
```
4. Run: `./k3s-kill.sh install`
5. Again, run: `sudo zfs set readonly=on your-value-here` but now with `readonly=on`.

For example (we take the value from above):
```
$ sudo zfs set readonly=on boot-pool/ROOT/24.04.0/usr
```
6. (Optional) Run: `./k3s-kill.sh cron` to set up your cron jobs (e.g. for Nextclolud)
7. Run: `./k3s-kill.sh kill` to kill the k3s server.

**Infos:**
  - This is tested on `TrueNAS-SCALE-23.10.1` and `TrueNAS-SCALE-24.04.0` all pre-cobia versions will not work.
  - You will have to reinstall after a system update.
  - When doing `./k3s-kill.sh restart` apps may or may not be re-deployed.

**Uninstall:** `./k3s-kill.sh uninstall`
## What it can do
`./k3s-killer.sh help`

```
TRUENAS SCALE ONLY! NO GUARANTEES!

k3s-killer is a tool that makes it possible to run k3s (kubernetes) without
k3s using so much CPU. This is experimental and may not work in all usecases!
First install the patches with the 'install' subcommand!

For applications that need the kubernetes cronjob stuff (e.g. nextcloud) refer
to the instructions output by the 'cron' subcommand.

It is highly recommended to look into this script first by yourself to get a hold of
what exactly it is doing.

Usage: k3s-killer.sh [kill|restart|cron|install|uninstall]
  kill: Kill the k3s server. This will make apps disappear from the GUI
  restart: Start k3s server after killing it.
  run: Run a command in a container while k3s is down (or active). Use the 'cron' subcommand for more info on it.
  cron: Help for running cronjobs while k3s is down (or active).
  ctr: Run the ctr programm while the k3s server is down (or active).
  install: Install patches for the k3s systemd service. This is needed for this to work. It will also backup the unpatched files.
  uninstall: Revert the patches for the k3s systemd service.
```

## Disclaimer
This script is not endorsed by ixsystems or the truenas scale developers whatsoever. Use with caution and look into the script beforehand to see what it is doing! If you are not comfortable with using this, do not.
