# TUIsh

![alt text](https://github.com/mrhappynice/tuish/blob/main/tuish.jpg?raw=true)

- Make executable:
```bash
chmod +x tuish.sh
chmod +x all_chat.sh
```

- Set keys:
```bash
export GROQ_API_KEY="put-key-here"
export MISTRAL_API_KEY="put-key-here"
export GOOGLE_API_KEY="put-key-here"
export OPENAI_API_KEY="put-key-here"
```

Install tmux, jq, and curl

To swtich to the chat pane: cttl + b + ;

Add the .tmux.conf file to your home dir to use mouse scrolling

On line 32 of tuish.sh, you can remove -Sl after the nano command if you do not want word wrapping and numbered lines
