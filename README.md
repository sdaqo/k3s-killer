# k3s-killer
A little script to reduce CPU usage in truenas scale systems with kubernetes running.

Refer to this thread to know why this exists: https://www.truenas.com/community/threads/k3s-server-uses-10-cpu-for-no-reason.91326/

## Install & Usage
1. Git clone this repo
2. Run: `./k3s-kill.sh install`
3. (Optional) Run: `./k3s-kill.sh cron` to set up your cron jobs (e.g. for Nextclolud)
4. Run: `./k3s-kill.sh kill` to kill the k3s server.

**Infos:**
  - This is tested on `TrueNAS-SCALE-23.10.1` all pre-cobia versions will not work.
  - You will have to reinstall after a system update.
  - When doing `./k3s-kill.sh restart` apps may or may not be re-deployed.

**Uninstall:** `./k3s-kill.sh uninstall`
## What it can do
```
TRUENAS SCALE ONLY! NO GUARANTEES!

k3s-killer is a tool that makes it possible to run k3s (kubernetes) without
k3s using so much CPU. This is experimental and may not work in all usecases!
First install the patches with the 'install' subcommand! Keep in mind that the
patches may be reset after a system update so you will have to run 'install' again
after the update.

For applications that need the kubernetes cronjob stuff (e.g. nextcloud) refer
to the instructions output by the 'cron' subcommand.

It is highly recommended to look into this script first by yourself to get a hold of
what exactly it is doing.

Usage: k3s-killer.sh [kill|restart|cron|install|uninstall]
  kill: Kill the k3s server and start a containerd service as replacement - this will make apps disappear from the GUI
  restart: Start k3s server after killing it and stop the containerd_inplace service.
  run: Run a command in a container while k3s is down. Use the 'cron' subcommand for more info on it.
  cron: Help for running cronjobs while k3s is down.
  ctr: Run the ctr programm while the k3s server is down.
  install: Install patches for the k3s systemd service. This is needed for this to work. It will also backup the unpatched files.
  uninstall: Revert the patches for the k3s systemd service.
```

## Disclaimer
This script is not endorsed by ixsystems or the truenas scale developers whatsoever. Use with caution and look into the script beforehand to see what it is doing! If you are not comfortable with using this, do not.
