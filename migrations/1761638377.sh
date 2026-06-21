echo "Turn off fcitx5 clipboard that is interferring with other applications"

mkdir -p ~/.config/fcitx5/conf
cp $SWARMARCHY_PATH/config/fcitx5/conf/clipboard.conf ~/.config/fcitx5/conf/

swarmarchy-restart-xcompose
