echo "Install socat so we can reactivate internal display when external display is removed"

swarmarchy-pkg-add socat
uwsm-app -- swarmarchy-hyprland-monitor-watch &
