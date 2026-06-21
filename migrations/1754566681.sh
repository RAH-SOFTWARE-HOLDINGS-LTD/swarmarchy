echo "Make new Osaka Jade theme available as new default"

if [[ ! -L ~/.config/swarmarchy/themes/osaka-jade ]]; then
  rm -rf ~/.config/swarmarchy/themes/osaka-jade
  git -C ~/.local/share/swarmarchy checkout -f themes/osaka-jade
  ln -nfs ~/.local/share/swarmarchy/themes/osaka-jade ~/.config/swarmarchy/themes/osaka-jade
fi
