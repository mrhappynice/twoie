#!/usr/bin/env bash
#
# tuish.sh
# Launches a tmux session with two panes:
# Left pane for editing a document, right pane for the chat interface.

SESSION_NAME="TUIsh"
DOC_FILE="${DOC_FILE:-document.txt}"

# If you have not created the doc yet, let's create an empty one
touch "$DOC_FILE"

# Check if tmux session exists; if so, attach; else create new.
tmux has-session -t "$SESSION_NAME" 2>/dev/null
if [ $? -eq 0 ]; then
  echo "Session '$SESSION_NAME' already exists. Attaching..."
  tmux attach-session -t "$SESSION_NAME"
  exit 0
fi

# Create a new tmux session but don't attach immediately
tmux new-session -d -s "$SESSION_NAME" bash

# In that session, rename the window
tmux rename-window -t "$SESSION_NAME:0" "Main"

# Split the window vertically (left/right)
# By default, the left pane is index 0 and the right pane is index 1.
tmux split-window -h -t "$SESSION_NAME:0"

# Pane 0 (left) -> open nano to edit the document
tmux send-keys -t "$SESSION_NAME:0.0" "nano -Sl \"$DOC_FILE\"" C-m

# Pane 1 (right) -> run the chat script
tmux send-keys -t "$SESSION_NAME:0.1" "./all_chat.sh" C-m

# Select left pane by default
tmux select-pane -t "$SESSION_NAME:0.0"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
