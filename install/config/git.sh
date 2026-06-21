# Set identification from install inputs
if [[ -n ${SWARMARCHY_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$SWARMARCHY_USER_NAME"
fi

if [[ -n ${SWARMARCHY_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$SWARMARCHY_USER_EMAIL"
fi
