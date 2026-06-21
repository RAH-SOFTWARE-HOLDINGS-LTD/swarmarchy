echo "Change to swarmarchy-nvim package"
swarmarchy-pkg-drop swarmarchy-lazyvim
swarmarchy-pkg-add swarmarchy-nvim

# Will trigger to overwrite configs or not to pickup new hot-reload themes
swarmarchy-nvim-setup
