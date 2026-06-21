echo "Change to openai-codex instead of openai-codex-bin"

if swarmarchy-pkg-present openai-codex-bin; then
    swarmarchy-pkg-drop openai-codex-bin
    swarmarchy-pkg-add openai-codex
fi
