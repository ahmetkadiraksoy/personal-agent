# Personal AI Agent

A terminal-based personal AI agent with persistent memory, notes, inbox
notifications, scheduled tasks, web search, Google Calendar integration,
local semantic retrieval, command autocomplete, and API usage tracking.

## Project Structure

The application has two main components:

-   `agent` --- interactive terminal client
-   `agent-server` --- FastAPI backend

The terminal client communicates with the local backend over HTTP.
Personal data, credentials, databases, and generated embedding indexes
are intentionally kept outside version control.

## Features

-   Conversational terminal interface
-   Persistent long-term memory
-   Notes knowledge base with semantic retrieval
-   Local E5 embeddings via Sentence Transformers
-   Inbox and notification management
-   Scheduled tasks
-   Google Calendar integration
-   Web search
-   API usage and estimated cost tracking
-   Slash-command autocomplete
-   macOS, Linux, Raspberry Pi OS, and Windows support

## Requirements

-   Python 3
-   An OpenAI API key
-   Internet access for OpenAI API and web-search functionality
-   Google Calendar credentials if Calendar integration is used
-   Git, if cloning the repository

Python dependencies are listed in `requirements.txt`.

------------------------------------------------------------------------

# Installation

## macOS

### 1. Install Python and Git

If Python 3 and Git are already installed, you can skip this step.

Using Homebrew:

``` bash
brew install python git
```

If Homebrew is not installed, Python can instead be installed from the
official Python distribution.

Verify:

``` bash
python3 --version
git --version
```

### 2. Get the project

Using Git:

``` bash
git clone https://github.com/ahmetkadiraksoy/personal-agent.git
cd personal-agent
```

Alternatively, download the repository from GitHub and extract it.

### 3. Create a virtual environment

``` bash
python3 -m venv .venv
source .venv/bin/activate
```

### 4. Install dependencies

``` bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### 5. Configure the environment

The agent uses a `.env` file to store configuration values that should **not** be included in the GitHub repository, particularly your OpenAI API key.

First, create a file named `.env` in the same directory as `agent` and `agent-server`.

On **macOS or Linux**:

```bash
nano .env
```

On **Windows**, you can create the file with Notepad:

```powershell
notepad .env
```

Add the following line:

```dotenv
OPENAI_API_KEY=your_openai_api_key_here
```

Replace `your_openai_api_key_here` with your actual OpenAI API key. For example:

```dotenv
OPENAI_API_KEY=sk-example123
```

Do not put quotation marks around the key unless your value specifically requires them.

If you do not already have an OpenAI API key, create one through the OpenAI API platform. An API key is separate from a ChatGPT subscription; API usage is billed through the OpenAI API account.

After saving the file, your project directory should look approximately like:

```text
personal-agent/
├── agent
├── agent-server
├── requirements.txt
├── README.md
├── .gitignore
└── .env
```

The `.env` file must remain local. **Do not upload or commit it to GitHub.** The repository's `.gitignore` is configured to exclude it.

To verify that the variable is being loaded correctly without displaying the secret itself, activate the project's virtual environment and run:

```bash
python -c "from dotenv import load_dotenv; import os; load_dotenv(); print('OpenAI API key configured:', bool(os.getenv('OPENAI_API_KEY')))"
```

A successful configuration should print:

```text
OpenAI API key configured: True
```

You can then start `agent-server` and the `agent` client as described below.
### 6. Make the programs executable

If necessary:

``` bash
chmod +x agent agent-server
```

### 7. Run the application

Start the server in one terminal:

``` bash
./agent-server
```

Then open another terminal, activate the same virtual environment, and
start the client:

``` bash
source .venv/bin/activate
./agent
```

------------------------------------------------------------------------

## Optional: Run the server automatically with launchd

This step is optional. On macOS, the equivalent of a Linux `systemd` service is a `launchd` LaunchAgent. This keeps the backend running in the background and can start it automatically when you log in.

First determine your project path:

```bash
cd /path/to/personal-agent
pwd
```

The example below assumes:

```text
User: aksoy
Project: /Users/aksoy/Documents/agent
Virtual environment: /Users/aksoy/Documents/agent/.venv
```

Create a LaunchAgent file:

```bash
nano ~/Library/LaunchAgents/com.personalagent.server.plist
```

Add:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.personalagent.server</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Users/aksoy/Documents/agent/.venv/bin/python</string>
        <string>/Users/aksoy/Documents/agent/agent-server</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/Users/aksoy/Documents/agent</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/aksoy/Documents/agent/agent-server.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/aksoy/Documents/agent/agent-server-error.log</string>
</dict>
</plist>
```

Change the username and paths if the project is installed elsewhere.

Load and start it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.personalagent.server.plist
```

### Service management

Check whether it is loaded:

```bash
launchctl print gui/$(id -u)/com.personalagent.server
```

Restart it:

```bash
launchctl kickstart -k gui/$(id -u)/com.personalagent.server
```

Stop and unload it:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.personalagent.server.plist
```

Load it again:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.personalagent.server.plist
```

View output:

```bash
tail -f /Users/aksoy/Documents/agent/agent-server.log
```

View errors:

```bash
tail -f /Users/aksoy/Documents/agent/agent-server-error.log
```

After the LaunchAgent is running, launch only the client when you want to use the agent:

```bash
cd /Users/aksoy/Documents/agent
source .venv/bin/activate
./agent
```

### After updating the code

If only `agent` changes, no backend restart is required.

If `agent-server` changes:

```bash
launchctl kickstart -k gui/$(id -u)/com.personalagent.server
```

If the `.plist` file itself changes, unload and reload it:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.personalagent.server.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.personalagent.server.plist
```

---

## Linux / Raspberry Pi OS

These instructions assume a Debian/Ubuntu/Raspberry Pi OS-based system.

### 1. Install system requirements

``` bash
sudo apt update
sudo apt install python3 python3-venv python3-pip git
```

Verify:

``` bash
python3 --version
git --version
```

### 2. Get the project

``` bash
git clone https://github.com/ahmetkadiraksoy/personal-agent.git
cd personal-agent
```

Or download and extract the repository manually.

### 3. Create a virtual environment

``` bash
python3 -m venv .venv
source .venv/bin/activate
```

### 4. Install dependencies

``` bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

On a Raspberry Pi, packages related to PyTorch, Transformers, and
Sentence Transformers may take longer to install than on a desktop
computer.

### 5. Configure the environment

The agent uses a `.env` file to store configuration values that should **not** be included in the GitHub repository, particularly your OpenAI API key.

First, create a file named `.env` in the same directory as `agent` and `agent-server`.

On **macOS or Linux**:

```bash
nano .env
```

On **Windows**, you can create the file with Notepad:

```powershell
notepad .env
```

Add the following line:

```dotenv
OPENAI_API_KEY=your_openai_api_key_here
```

Replace `your_openai_api_key_here` with your actual OpenAI API key. For example:

```dotenv
OPENAI_API_KEY=sk-example123
```

Do not put quotation marks around the key unless your value specifically requires them.

If you do not already have an OpenAI API key, create one through the OpenAI API platform. An API key is separate from a ChatGPT subscription; API usage is billed through the OpenAI API account.

After saving the file, your project directory should look approximately like:

```text
personal-agent/
├── agent
├── agent-server
├── requirements.txt
├── README.md
├── .gitignore
└── .env
```

The `.env` file must remain local. **Do not upload or commit it to GitHub.** The repository's `.gitignore` is configured to exclude it.

To verify that the variable is being loaded correctly without displaying the secret itself, activate the project's virtual environment and run:

```bash
python -c "from dotenv import load_dotenv; import os; load_dotenv(); print('OpenAI API key configured:', bool(os.getenv('OPENAI_API_KEY')))"
```

A successful configuration should print:

```text
OpenAI API key configured: True
```

You can then start `agent-server` and the `agent` client as described below.
### 6. Make the programs executable

``` bash
chmod +x agent agent-server
```

### 7. Run the application

Start the server:

``` bash
./agent-server
```

In another terminal:

``` bash
source .venv/bin/activate
./agent
```

## Optional: Run the server automatically with systemd

This step is optional. On Linux and Raspberry Pi OS, the backend can run continuously as a `systemd` service. This means it can start automatically at boot and you do not need to leave a terminal open.

The following example assumes:

```text
User: aksoy
Project: /home/aksoy/Documents/agent
Virtual environment: /home/aksoy/Documents/agent/.venv
```

If your username or project path differs, change the paths accordingly.

Create the service:

```bash
sudo nano /etc/systemd/system/agent-server.service
```

Use:

```ini
[Unit]
Description=Personal AI Agent Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=aksoy
WorkingDirectory=/home/aksoy/Documents/agent
ExecStart=/home/aksoy/Documents/agent/.venv/bin/python /home/aksoy/Documents/agent/agent-server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Reload `systemd`:

```bash
sudo systemctl daemon-reload
```

Enable the service at boot and start it immediately:

```bash
sudo systemctl enable --now agent-server
```

### Service management

Check status:

```bash
systemctl status agent-server
```

Start:

```bash
sudo systemctl start agent-server
```

Stop:

```bash
sudo systemctl stop agent-server
```

Restart:

```bash
sudo systemctl restart agent-server
```

Enable automatic startup:

```bash
sudo systemctl enable agent-server
```

Disable automatic startup:

```bash
sudo systemctl disable agent-server
```

View recent logs:

```bash
journalctl -u agent-server -n 100
```

Follow logs live:

```bash
journalctl -u agent-server -f
```

After the service is running, you only need to launch the client:

```bash
cd /home/aksoy/Documents/agent
source .venv/bin/activate
./agent
```

### After updating the code

If only `agent` changes, no server restart is required.

If `agent-server` changes:

```bash
sudo systemctl restart agent-server
```

If the `.service` file itself changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart agent-server
```

------------------------------------------------------------------------

## Windows

PowerShell is recommended.

### 1. Install Python and Git

Install Python 3 and Git for Windows.

During Python installation, enable the option to add Python to `PATH`.

Verify in PowerShell:

``` powershell
python --version
git --version
```

If `python` is unavailable but the Python launcher is installed, try:

``` powershell
py --version
```

### 2. Get the project

``` powershell
git clone https://github.com/ahmetkadiraksoy/personal-agent.git
cd personal-agent
```

Alternatively, download the repository ZIP from GitHub and extract it.

### 3. Create a virtual environment

Using Python:

``` powershell
python -m venv .venv
```

Or:

``` powershell
py -m venv .venv
```

Activate it:

``` powershell
.\.venv\Scripts\Activate.ps1
```

If PowerShell prevents activation because of its execution policy, the
environment can instead be used without activation by invoking its
Python executable directly, or the execution policy can be configured
according to the organization's security requirements.

### 4. Install dependencies

``` powershell
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### 5. Configure the environment

The agent uses a `.env` file to store configuration values that should **not** be included in the GitHub repository, particularly your OpenAI API key.

First, create a file named `.env` in the same directory as `agent` and `agent-server`.

On **macOS or Linux**:

```bash
nano .env
```

On **Windows**, you can create the file with Notepad:

```powershell
notepad .env
```

Add the following line:

```dotenv
OPENAI_API_KEY=your_openai_api_key_here
```

Replace `your_openai_api_key_here` with your actual OpenAI API key. For example:

```dotenv
OPENAI_API_KEY=sk-example123
```

Do not put quotation marks around the key unless your value specifically requires them.

If you do not already have an OpenAI API key, create one through the OpenAI API platform. An API key is separate from a ChatGPT subscription; API usage is billed through the OpenAI API account.

After saving the file, your project directory should look approximately like:

```text
personal-agent/
├── agent
├── agent-server
├── requirements.txt
├── README.md
├── .gitignore
└── .env
```

The `.env` file must remain local. **Do not upload or commit it to GitHub.** The repository's `.gitignore` is configured to exclude it.

To verify that the variable is being loaded correctly without displaying the secret itself, activate the project's virtual environment and run:

```bash
python -c "from dotenv import load_dotenv; import os; load_dotenv(); print('OpenAI API key configured:', bool(os.getenv('OPENAI_API_KEY')))"
```

A successful configuration should print:

```text
OpenAI API key configured: True
```

You can then start `agent-server` and the `agent` client as described below.
### 6. Run the application

The `agent` and `agent-server` files use Unix-style executable behavior,
so on Windows the most portable approach is to invoke them through
Python:

``` powershell
python .\agent-server
```

Then open another PowerShell window, activate the virtual environment,
and run:

``` powershell
python .\agent
```

If the scripts depend on Unix-specific behavior in a future version,
Windows Subsystem for Linux (WSL) is an alternative way to run the Linux
installation.

------------------------------------------------------------------------

## Optional: Run the server automatically with Windows Task Scheduler

This step is optional. On Windows, Task Scheduler can provide the equivalent behavior: start `agent-server` automatically when you sign in and keep the terminal client separate.

The example below assumes:

```text
Project: C:\Users\YOUR_USERNAME\Documents\personal-agent
Virtual environment: C:\Users\YOUR_USERNAME\Documents\personal-agent\.venv
```

Replace the paths with your actual installation location.

### Create the scheduled task

1. Open **Task Scheduler**.
2. Select **Create Task**.
3. On **General**:
   - Name it `Personal AI Agent Server`.
   - Select **Run only when user is logged on** unless you specifically need background execution before login.
4. On **Triggers**:
   - Create a trigger **At log on** for your user account.
5. On **Actions**, create **Start a program**.
6. For **Program/script**, enter:

```text
C:\Users\YOUR_USERNAME\Documents\personal-agent\.venv\Scripts\python.exe
```

7. For **Add arguments**, enter:

```text
C:\Users\YOUR_USERNAME\Documents\personal-agent\agent-server
```

8. For **Start in**, enter:

```text
C:\Users\YOUR_USERNAME\Documents\personal-agent
```

9. Save the task.

### Service management

Start the task manually from PowerShell:

```powershell
Start-ScheduledTask -TaskName "Personal AI Agent Server"
```

Check its state:

```powershell
Get-ScheduledTask -TaskName "Personal AI Agent Server"
```

Stop it:

```powershell
Stop-ScheduledTask -TaskName "Personal AI Agent Server"
```

Disable automatic execution:

```powershell
Disable-ScheduledTask -TaskName "Personal AI Agent Server"
```

Enable it again:

```powershell
Enable-ScheduledTask -TaskName "Personal AI Agent Server"
```

After the scheduled task is running, start only the client when needed:

```powershell
cd C:\Users\YOUR_USERNAME\Documents\personal-agent
.\.venv\Scripts\Activate.ps1
python .\agent
```

### After updating the code

If only `agent` changes, no backend restart is required.

If `agent-server` changes, restart the scheduled task:

```powershell
Stop-ScheduledTask -TaskName "Personal AI Agent Server"
Start-ScheduledTask -TaskName "Personal AI Agent Server"
```

If you change the task configuration itself, update it in Task Scheduler.

---

# Configuration

The project keeps configuration and private data locally.

At minimum, configure the OpenAI API credentials expected by
`agent-server` in `.env`.

A typical installation will contain files similar to:

``` text
personal-agent/
├── agent
├── agent-server
├── requirements.txt
├── README.md
├── .gitignore
├── .env                       # local only
├── memory.json                # local only
├── notes.db                   # local only
└── ...
```

Do not put API keys directly into `agent` or `agent-server`.

## Google Calendar

Google Calendar support is optional.

If Calendar integration is enabled, Google OAuth credentials and
generated authentication tokens should remain local. Do not commit
Google credential or token files to the repository.

A new machine may require Google authorization again because
authentication tokens are deliberately not stored in GitHub.

------------------------------------------------------------------------

# Commands

## Knowledge

``` text
/memory                    List memories
/memory <query|number>     Search or open a memory
/notes                     List notes
/notes <query|number>      Search or open a note
/history                   Show chat history
```

## Inbox

``` text
/inbox                     List inbox
/inbox <number>            Open an entry
/inbox read <number>       Mark an entry as read
/inbox unread <number>     Mark an entry as unread
/inbox remove <number>     Remove an entry
```

## Tasks

``` text
/tasks                     List tasks
/tasks run <number>        Run a task
/tasks enable <number>     Enable a task
/tasks disable <number>    Disable a task
/tasks remove <number>     Remove a task
```

## Session

``` text
/stateless                 Toggle stateless mode
/clear                     Clear conversation history
```

## Information

``` text
/status                    Show agent status
/usage                     Show usage and estimated API costs
/rules                     Show behavior rules
/help                      Show command help
```

## Exit

``` text
/exit                      Exit the client
/quit                      Exit the client
```

Tab completion is available for commands and supported items.

------------------------------------------------------------------------

# Private and Generated Files

The repository should contain source code and configuration templates,
not personal data.

Files such as the following should remain local:

``` text
.env
google_token.json
credentials.json
client_secret*.json
memory.json
notes.db
rules.json
memory_embeddings.npz
note_embeddings.npz
```

The project's `.gitignore` should exclude these files.

Never commit an OpenAI API key, Google OAuth token, client secret,
personal memory database, or other credential.

------------------------------------------------------------------------

# Moving to a New Computer

To recreate the agent on another computer:

1.  Clone or download the repository.
2.  Create a new Python virtual environment.
3.  Install `requirements.txt`.
4.  Create the local `.env` configuration.
5.  Copy personal data files only if you intentionally want to migrate
    them.
6.  Reauthorize Google Calendar if necessary.
7.  Start `agent-server`.
8.  Start `agent`.

The `.venv` directory should **not** be copied between operating systems
or computers. Create a fresh virtual environment on each machine.

------------------------------------------------------------------------

# Platform Notes

The application-level Python code is largely the same across macOS,
Linux, and Windows. Differences mainly involve:

-   Installing Python and system packages
-   Virtual-environment activation commands
-   Executable script behavior
-   Background-service management
-   Platform-specific binary dependencies

Sentence Transformers and PyTorch may install different binary packages
depending on the operating system and CPU architecture. This is
expected.

For persistent background operation:

-   Linux / Raspberry Pi OS: `systemd`
-   macOS: `launchd`
-   Windows: Task Scheduler or a Windows service

These are optional; the agent can be run manually from a terminal on all
supported platforms.

------------------------------------------------------------------------

# License

Private project. No license is currently specified.
