# TUIsh

Access models from OpenAI, Google, Groq, SambaNova, and Deepseek(so far). Paste and edit responses all from your terminal. Use on any Linux based command line including Termux on Android with minimal requirements. Installation is super simple. Just use your favorite package manager to make sure you have tmux, jq, curl and dialog installed, chmod the shell files and run tuish.sh.

![alt text](https://github.com/mrhappynice/tuish/blob/main/tuish.jpg?raw=true)

- Easily select provider and model:
![alt text](https://github.com/mrhappynice/tuish/blob/main/tuish_dialog.jpg?raw=true)

##

### edit export_keys file, add your keys then:
```bash
source export_keys
```
Or set keys:
```bash
export GROQ_API_KEY="put-key-here"
export GOOGLE_API_KEY="put-key-here"
export OPENAI_API_KEY="put-key-here"
export DS_API_KEY="put-key-here"
export SN_API_KEY="put-key-here"
```

### Make executable:
```bash
chmod +x tuish.sh
chmod +x all_chat.sh
```

Use your favorite package manager to install  dialog, tmux, jq, and curl

To swtich to the chat pane: cttl + b + ;

Add the .tmux.conf file to your home dir to use mouse scrolling

On line 32 of tuish.sh, you can remove -Sl after the nano command if you do not want word wrapping and numbered lines

### To run simply:
```bash
./tuish.sh
```

##


