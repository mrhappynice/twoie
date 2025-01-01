#!/usr/bin/env bash
#
# all_chat.sh
# A simple chat interface supporting multiple LLM services:
#   - Ollama (local server)   [default]
#   - Groq (OpenAI-compatible endpoint)
#   - Google Generative Language
#   - Deepseek
#   - (Optional) OpenAI
#   - SambaNova
#
# Uses jq for building/parsing JSON, and includes a system message.

# -----------------------------------------------------------------------------
# -- Configuration & Defaults -------------------------------------------------

: "${OLLAMA_API_URL:=http://localhost:11434/api/generate}"        # Example local
: "${OLLAMA_TAGS_URL:=http://localhost:11434/api/tags}" # Ollama tags endpoint
: "${DEFAULT_MODEL_OLLAMA:=hf.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q4_K_M}"
: "${DEFAULT_MODEL_GROQ:=llama3-8b-8192}"
: "${DEFAULT_MODEL_GOOGLE:=gemini-1.5-flash}"
: "${DEFAULT_MODEL_DEEPSEEK:=deepseek-chat}"
: "${DEFAULT_MODEL_OPENAI:=gpt-4o-mini}"
: "${DEFAULT_MODEL_SAMBANOVA:=Qwen2.5-72B-Instruct}"

SYSTEM_MSG="You are a helpful assistant."

# Which service is currently selected?  (ollama|groq|google|deepseek|openai|sambanova)
SELECTED_SERVICE="sambanova"
SELECTED_MODEL="$DEFAULT_MODEL_SAMBANOVA"

echo "      .-::TUIsh::-.         "
echo "Switch to chat pane ctrl+b+;"
echo "Special commands:"
echo "  /flush      - Clear context"
echo "  /switch     - Switch to editor"
echo "  /paste      - Paste last response"
echo "  /help       - Show commands"
echo "  /select-llm - Use dialog to pick LLM service & model"
echo "  Ctrl-C      - Quit."
echo

# -----------------------------------------------------------------------------
# We maintain a JSON array of messages in a variable called MESSAGES_JSON.
# Start with a single system message.

MESSAGES_JSON=$(jq -n --arg content "$SYSTEM_MSG" '[{"role":"system","content":$content}]')

# Keep track of the last assistant response in this variable
LAST_ASSISTANT_CONTENT=""

# -----------------------------------------------------------------------------
# Function to append a new role/content pair to MESSAGES_JSON
add_message() {
  local role="$1"
  local content="$2"
  MESSAGES_JSON=$(echo "$MESSAGES_JSON" | jq --arg role "$role" --arg content "$content" \
    '. + [{role: $role, content: $content}]')
}

# -----------------------------------------------------------------------------
# Function to build a single text prompt from MESSAGES_JSON (used by Ollama)
build_prompt_ollama() {
  local prompt
  prompt=$(echo "$MESSAGES_JSON" | jq -r '
    map(
      if .role == "system" then
        "System: " + .content + "\n\n"
      elif .role == "user" then
        "User: " + .content + "\n\n"
      elif .role == "assistant" then
        "Assistant: " + .content + "\n\n"
      else
        ""
      end
    ) | join("")
  ')
  echo "$prompt"
}

# -----------------------------------------------------------------------------
# Function to build OpenAI-compatible messages array (used by Groq / OpenAI / Deepseek / SambaNova)
build_messages_openai_format() {
  # We already store the conversation in a role+content array, which is actually
  # OpenAI-compatible. So we can simply pass MESSAGES_JSON as is, if we want.
  echo "$MESSAGES_JSON"
}

# -----------------------------------------------------------------------------
# Function to build Google Generative Language request body
build_prompt_google() {
  # We flatten the conversation into a single text chunk or combine
  # system + user messages, etc. For simplicity, let's just combine them:
  local text
  text=$(echo "$MESSAGES_JSON" | jq -r '
    map(
      (if .role == "system" then "[System]: " else "" end) +
      (if .role == "user" then "[User]: " else "" end) +
      (if .role == "assistant" then "[Assistant]: " else "" end) +
      .content +
      "\n\n"
    ) | join("")
  ')
  # Return a JSON that Google expects
  # "contents" => array => "parts" => array => "text"
  jq -n --arg text "$text" '
    {
      "contents": [
        {
          "parts": [
            {"text": $text}
          ]
        }
      ]
    }
  '
}

# -----------------------------------------------------------------------------
# Function to fetch available models from Ollama
get_ollama_models() {
  local models
  # Use OLLAMA_TAGS_URL variable for API endpoint
  models=$(curl -s "$OLLAMA_TAGS_URL" | jq -r '.models[].name')
  if [ -z "$models" ]; then
    echo "Error: Could not fetch models from Ollama." >&2
    return 1
  fi
  echo "$models"
}

# -----------------------------------------------------------------------------
# Function to fetch available models from Google Generative AI
get_google_models() {
  local models
  models=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GOOGLE_API_KEY" | jq -r '.models[].name')
  if [ -z "$models" ]; then
    echo "Error: Could not fetch models from Google Generative AI." >&2
    return 1
  fi
  echo "$models"
}

# -----------------------------------------------------------------------------
# Helper function to select LLM service & model with dialog
select_llm() {
  # 1) Pick the service
  SELECTED_SERVICE=$(dialog --clear --title "Select LLM Service" --menu "Choose one:" 15 50 6 \
    "ollama" "Local Ollama Server" \
    "groq" "Groq LLM Service" \
    "google" "Google Generative Language" \
    "deepseek" "Deepseek" \
    "openai" "OpenAI Chat Completions" \
    "sambanova" "SambaNova" \
    2>&1 >/dev/tty)
  clear

  # If user pressed ESC or canceled, preserve the old selection
  if [ -z "$SELECTED_SERVICE" ]; then
    echo "[No service selected. Keeping previous: $SELECTED_SERVICE]"
    return
  fi

  # 2) Pick the model for that service
  case "$SELECTED_SERVICE" in
    "ollama")
      # Fetch models from Ollama dynamically
      local ollama_models
      ollama_models=$(get_ollama_models)
      if [ $? -ne 0 ]; then return 1; fi # Exit if fetching models failed

      # Build dialog arguments dynamically
      local dialog_args=()
      while read -r model; do
        dialog_args+=("$model" "$model")
      done <<< "$ollama_models"

      # Display dialog with fetched models
      SELECTED_MODEL=$(dialog --clear --title "Select Model" --menu "Choose a model:" 15 60 "$((${#dialog_args[@]}/2))" "${dialog_args[@]}" 2>&1 >/dev/tty)
      clear
      if [ -z "$SELECTED_MODEL" ]; then
        SELECTED_MODEL="$DEFAULT_MODEL_OLLAMA"
      fi
      ;;
    "groq")
      SELECTED_MODEL=$(dialog --clear --title "Select Model" --menu "Choose a model:" 15 60 4 \
        "$DEFAULT_MODEL_GROQ"  "Llama3-8b-8192" \
        "gemma2-9b-it"        "gemma2-9b-it" \
        "llama-3.3-70b-versatile"        "llama-3.3-70b-versatile" \
        "llama-3.1-8b-instant"        "llama-3.1-8b-instant" \
        "mixtral-8x7b-32768"        "mixtral-8x7b-32768" \
        "llama-3.2-3b-preview"        "llama-3.2-3b-preview" \
        2>&1 >/dev/tty)
      clear
      if [ -z "$SELECTED_MODEL" ]; then
        SELECTED_MODEL="$DEFAULT_MODEL_GROQ"
      fi
      ;;
    "google")
      # Fetch models from Google dynamically
      local google_models
      google_models=$(get_google_models)
      if [ $? -ne 0 ]; then return 1; fi

      # Build dialog arguments dynamically
      local dialog_args=()
      while read -r model; do
        dialog_args+=("$model" "$model")
      done <<< "$google_models"

      # Display dialog with fetched models
      SELECTED_MODEL=$(dialog --clear --title "Select Model" --menu "Choose a model:" 15 60 "$((${#dialog_args[@]}/2))" "${dialog_args[@]}" 2>&1 >/dev/tty)
      clear
      if [ -z "$SELECTED_MODEL" ]; then
        SELECTED_MODEL="$DEFAULT_MODEL_GOOGLE"
      fi
      ;;
    "deepseek")
        SELECTED_MODEL="deepseek-chat"
    ;;
    "openai")
      SELECTED_MODEL=$(dialog --clear --title "Select Model" --menu "Choose a model:" 15 60 4 \
        "$DEFAULT_MODEL_OPENAI"  "4o mini" \
        "chatgpt-4o-latest"                  "ChatGPT 4o" \
        "o1"                  "o1" \
        "o1-mini"                  "o1-mini" \
        2>&1 >/dev/tty)
      clear
      if [ -z "$SELECTED_MODEL" ]; then
        SELECTED_MODEL="$DEFAULT_MODEL_OPENAI"
      fi
      ;;
    "sambanova")
      SELECTED_MODEL=$(dialog --clear --title "Select Model" --menu "Choose a model:" 15 60 2 \
        "$DEFAULT_MODEL_SAMBANOVA"  "Qwen2.5-72B-Instruct" \
        "Meta-Llama-3.1-405B-Instruct"                  "Meta-Llama-3.1-405B-Instruct" \
        "Meta-Llama-3.1-8B-Instruct"                  "Meta-Llama-3.1-8B-Instruct" \
        "Meta-Llama-3.2-3B-Instruct"                  "Meta-Llama-3.2-3B-Instruct" \
        "Qwen2.5-Coder-32B-Instruct"                  "Qwen2.5-Coder-32B-Instruct" \
        "QwQ-32B-Preview"                  "QwQ-32B-Preview" \
        "Qwen2.5-72B-Instruct"                  "Qwen2.5-72B-Instruct" \
        2>&1 >/dev/tty)
      clear
      if [ -z "$SELECTED_MODEL" ]; then
        SELECTED_MODEL="$DEFAULT_MODEL_SAMBANOVA"
      fi
      ;;

  esac

  echo "Selected service: $SELECTED_SERVICE"
  echo "Selected model:   $SELECTED_MODEL"
}

# -----------------------------------------------------------------------------
# Main Loop
# -----------------------------------------------------------------------------

while true; do
  echo -n "> "
  if ! read -r USER_INPUT; then
    # If we get EOF (Ctrl-D) or a read error, just exit
    echo
    exit 0
  fi

  # Check for special commands
  case "$USER_INPUT" in
    /flush)
      # Reset to just the system message
      MESSAGES_JSON=$(jq -n --arg content "$SYSTEM_MSG" '[{"role":"system","content":$content}]')
      echo "[Context cleared. System message still present.]"
      continue
      ;;
    /switch)
      # Switch focus to the left tmux pane (pane 0)
      tmux select-pane -t 0
      continue
      ;;
    /paste)
      # Paste last assistant response into left pane
      if [ -n "$LAST_ASSISTANT_CONTENT" ]; then
        echo "$LAST_ASSISTANT_CONTENT" | tmux load-buffer -
        tmux select-pane -t 0
        tmux paste-buffer -t 0
      else
        echo "[No assistant response available yet to paste.]"
      fi
      continue
      ;;
    /help)
		echo "      .-::TUIsh::-.         "
		echo "Switch to chat pane ctrl+b+;"
		echo "Special commands:"
		echo "  /flush      - Clear context"
		echo "  /switch     - Switch to editor"
		echo "  /paste      - Paste last response"
		echo "  /help       - Show commands"
		echo "  /select-llm - Use dialog to pick LLM service & model"
		echo "  Ctrl-C      - Quit."
		echo
	  continue
      ;;
    /select-llm)
      select_llm
      continue
      ;;
    "")
      # If user just hits Enter, skip calling the API
      continue
      ;;
  esac

  # 1) Append user's message to the conversation
  add_message "user" "$USER_INPUT"

  # Depending on which service is selected, build the request differently
  case "$SELECTED_SERVICE" in

    # ----------------- O L L A M A -----------------
    ollama)
      PROMPT_TEXT=$(build_prompt_ollama)
      JSON_BODY=$(jq -n \
        --arg model "$SELECTED_MODEL" \
        --arg prompt "$PROMPT_TEXT" \
        '{
          model: $model,
          prompt: $prompt,
          stream: false
        }'
      )
      RESPONSE=$(curl -s -X POST "$OLLAMA_API_URL" \
        -H "Content-Type: application/json" \
        -d "$JSON_BODY")
      # Extract the assistant's message from Ollama
      ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.response // empty')
      ;;

    # ----------------- G R O Q -----------------
    groq)
      # Groq follows an OpenAI-compatible request format
      # Build an array of messages [ { role, content }, ... ]
      JSON_BODY=$(jq -n \
        --arg model "$SELECTED_MODEL" \
        --argjson msgs "$(build_messages_openai_format)" \
        '{
          model: $model,
          messages: $msgs
        }'
      )
      RESPONSE=$(curl -s https://api.groq.com/openai/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -d "$JSON_BODY")
      # Parse out the assistant's message
      ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
      ;;

    # ----------------- G O O G L E -----------------
    google)
      # Google Generative Language v1beta
      # Model is appended to the URL: /v1beta/models/<model>:generateContent
      # Build request body
      JSON_BODY=$(build_prompt_google)

      RESPONSE=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/$SELECTED_MODEL:generateContent?key=$GOOGLE_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$JSON_BODY")

      ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')
      ;;

    # ----------------- D E E P S E E K -----------------
    deepseek)
      JSON_BODY=$(jq -n \
        --arg model "$SELECTED_MODEL" \
        --argjson msgs "$(build_messages_openai_format)" \
        '{
          model: $model,
          messages: $msgs,
          stream: false
        }'
      )

      RESPONSE=$(curl -s https://api.deepseek.com/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DS_API_KEY" \
        -d "$JSON_BODY")

      ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
      ;;

    # ----------------- O P E N A I -----------------
    openai)
      JSON_BODY=$(jq -n \
        --arg model "$SELECTED_MODEL" \
        --argjson msgs "$(build_messages_openai_format)" \
        '{
          model: $model,
          messages: $msgs
        }'
      )
      RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$JSON_BODY")

      ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
      ;;

    # ----------------- S A M B A N O V A -----------------
    sambanova)
      JSON_BODY=$(jq -n \
        --arg model "$SELECTED_MODEL" \
        --argjson msgs "$(build_messages_openai_format)" \
        '{
          model: $model,
          messages: $msgs
        }'
      )

      RESPONSE=$(curl -s https://api.sambanova.ai/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $SN_API_KEY" \
        -d "$JSON_BODY")

      ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
      ;;

    *)
      # Default fallback if service unknown
      echo "[Error: No valid service selected.]"
      continue
      ;;
  esac

  # Check for empty response
  if [ -z "$ASSISTANT_CONTENT" ]; then
    echo "Assistant: [No response or error]"
    continue
  fi

  # 5) Append the assistant's response to the conversation
  add_message "assistant" "$ASSISTANT_CONTENT"

  # Save it in LAST_ASSISTANT_CONTENT
  LAST_ASSISTANT_CONTENT="$ASSISTANT_CONTENT"

  # Print out the assistant's message
  echo -e "\nAssistant: $ASSISTANT_CONTENT\n"
done
