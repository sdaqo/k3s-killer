#!/bin/bash

K3S_KILL="/usr/local/bin/k3s-kill.sh"
K3S_KILL_PATCH=$(cat <<'EOF'
31c31
< killtree $({ set +x; } 2>/dev/null; getshims; set -x)
---
> # killtree $({ set +x; } 2>/dev/null; getshims; set -x)
41c41
< do_unmount_and_remove '/run/k3s'
---
> # do_unmount_and_remove '/run/k3s'
EOF
)

K3S_SERVICE="/lib/systemd/system/k3s.service"
K3S_SERVICE_PATCH=$(cat <<'EOF'
21c21
< Restart=always
---
> Restart=never
EOF
)

APP_POOL="/mnt/$(cli -c 'app kubernetes config' | grep -oP '(?<=dataset\s\|\s).*(?=\s\|)')"


##################################
#        Utility functions       #
##################################

check_root () {
  if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
  fi
}

continue_prompt () {
  read -p "$1 (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
}


patch_file () {
  mkdir -p "backup"
  cp $2 backup/$(basename "$2")

  echo 
  echo "Backed up $2 to backup/$(basename ${2})"
  echo 
  echo "Patching $2..."
  echo 
  echo "Testing Patch:"
  echo "$1"
  patch --forward --dry-run "$2" <<< "$1"
  echo

  if [ $? -eq 0 ]; then
    echo "Test successful, the patch can be applied!"
    continue_prompt "Continue?"
    patch --no-backup-if-mismatch --forward "$2" <<< "$1"
    echo "Patch applied!"
  else
    echo "Patch can not be applied! Maybe you already patched the file once? If so try `k3s-killer.sh uninstall` else contact the developer!" && exit 0
  fi
}

check_patches () {
  if ! patch -s -R -f --dry-run  "$K3S_KILL" <<< "$K3S_KILL_PATCH"; then
    echo "Patches not applied run the 'install' subcommand first!" && exit 0
  fi

  if ! patch -s -R -f --dry-run  "$K3S_SERVICE" <<< "$K3S_SERVICE_PATCH"; then
    echo "Patches not applied run the 'install' subcommand first!" && exit 0
  fi
}

start_stop_containerd () {
  if [[ "$1" == "stop" ]]; then
    systemctl is-failed --quiet containerd_inplace && systemctl reset-failed --quiet containerd_inplace
    systemctl stop containerd_inplace
  elif [[ "$1" == "start" ]]; then
    systemctl is-active --quiet k3s && echo "K3S is already running, will not start an extra containerd instance!" && return

    CD_BIN="$APP_POOL/k3s/data/current/bin/containerd"
    CD_STATE="/run/k3s/containerd"
    CD_ROOT="$APP_POOL/k3s/agent/containerd"
    CD_CONFIG="$APP_POOL/k3s/agent/etc/containerd/config.toml"

    if [[ $(systemctl is-active containerd_inplace) == "active" ]]; then
      echo "The `containerd_inplace` service is already loaded, restarting it..."
      systemctl reload-or-restart containerd_inplace
    else
      echo "The 'containerd_inplace' service is now being loaded and started."

      systemd-run -u containerd_inplace \
        -p Delegate=yes -p KillMode=process --collect \
        $CD_BIN \
        -c $CD_CONFIG --state $CD_STATE \
        -a $CD_STATE/containerd.sock --root $CD_ROOT
      sleep 1
    fi
  fi
    
}

##################################
#        Command functions       #
##################################

kill_k3s () {
  check_root
  check_patches

  k3s_server_pid=$(systemctl status k3s | grep -oP '\d+(?= "\/usr\/local\/bin\/k3s server")')
  echo "Killing k3s server with PID $k3s_server_pid..."
  kill -9 "$k3s_server_pid"
}

run_command () {
  check_root
  check_patches

  start_stop_containerd "start"

  CTR_BIN="$APP_POOL/k3s/data/current/bin/ctr"
  ADDRESS="/run/k3s/containerd/containerd.sock"
  NS="k8s.io"
  CONTAINER_REGEX="$1"
  EXEC_ID="$2"
  EXEC_USER="$3"
  COMMAND="${@:4}"

  CONTAINER=""

  for c in $($CTR_BIN -a "$ADDRESS" -n "$NS" containers ls | grep "$CONTAINER_REGEX" | awk '{ print $1 }'); do
      $CTR_BIN -a "$ADDRESS" -n "$NS" task ls | grep -q "$c" && CONTAINER="$c" && break
  done

  if [ -n "$3" ]; then
    $CTR_BIN -a "$ADDRESS" -n "$NS" task exec --exec-id $EXEC_ID --user $EXEC_USER $CONTAINER $COMMAND
  else
    $CTR_BIN -a "$ADDRESS" -n "$NS" task exec --exec-id $EXEC_ID $CONTAINER $COMMAND
  fi

  start_stop_containerd "stop"
}

run_ctr () {
  check_root
  check_patches

  start_stop_containerd "start"
  $APP_POOL/k3s/data/current/bin/ctr $@
  start_stop_containerd "stop"
}

restart_k3s () {
  check_root
  check_patches

  if [[ $(systemctl status containerd_inplace | grep -q 'Active') ]]; then
    start_stop_containerd "stop"
  fi
  
  echo "Starting k3s..."
  systemctl start k3s
}

install_stuff () {
  check_root

  echo "Patching your k3s service so apps can run without it!"
  echo "It is highly recommended to backup before doing this!"
  continue_prompt "Continue?"
  patch_file "$K3S_KILL_PATCH" "$K3S_KILL"
  patch_file "$K3S_SERVICE_PATCH" "$K3S_SERVICE"
  systemctl daemon-reload
  echo "Successfully installed k3s-killer."
  continue_prompt "You will now have to restart the k3s service, this may or may not re-deploy your apps, do you want to do that? Alternatively you can also restart your system."
  systemctl restart k3s
}

uninstall_stuff() {
  check_root

  echo "Reverting patches..."
  patch -R "$K3S_KILL" <<< "$K3S_KILL_PATCH"
  patch -R "$K3S_SERVICE" <<< "$K3S_SERVICE_PATCH"
  systemctl daemon-reload
}

cron_help () {
  script=$(cat <<EOF
#!/bin/bash

# Check if the k3s server is running, if yes exit.
# Comment this out if you do not want this (for example if you
# are using this as a general cron job script)
systemctl is-active --quiet k3s && exit 1


# Find the correct container to talk to, to find it you can use 'k3s ctr' while k3s is running
# use 'k3s ctr containers ls' to list all running containers, then grep your way
# to your own container, replace the CONTAINER_REGEX variable with it, normally the name
# of the application should suffice!
CONTAINER_REGEX="nextcloud"

# Now run your cron tasks, the first argument here is the 
# container regex, the second is the exec id (just use any arbitrary number, 
# just keep in mind that if running two command ideally you should use two diffrent exec ids)
# the fourth is the user to run the command as and the last one is the command to run.
#
# In this case we run the nextcloud cron job and the preview generator with exec id 3 and 4
# respectivly and as user with id 33 (www-data), the user may be specified with the name
# or the id, it should not matter (normally).

/path/to/k3s-killer.sh run "\$CONTAINER_REGEX" 3 33 "php -f /var/www/html/cron.php" 
/path/to/k3s-killer.sh run "\$CONTAINER_REGEX" 4 33 "php -f /var/www/html/occ preview:pre-generate"

# Add your own commands
EOF
)
  echo "This is a guide on how to use your system cron to replace the kubernetes cron service thingy. This is especially helpful for Nextcloud.

The steps are as follows:
- write your script
- add a cron job in the truenas ui
- enjoy - I guess...

The following is a template/example for a cron shell script:
$script 
  " | less
  continue_prompt "Do you want to write the template Script to a file?"
  echo "$script" > cron_example.sh
  chmod +x cron_example.sh
}

print_help () {
  echo "
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
  "
}

case "$1" in
  "kill") kill_k3s ${@:2}
  ;;
  "restart") restart_k3s ${@:2}
  ;;
  "install") install_stuff ${@:2}
  ;;
  "uninstall") uninstall_stuff ${@:2}
  ;;
  "run") run_command ${@:2}
  ;;
  "ctr") run_ctr ${@:2}
  ;;
  "cron") cron_help ${@:2}
  ;;
  "help"|"-h"|"--help") print_help ${@:2}
  ;;
  *) print_help ${@:2}
  ;;
esac
