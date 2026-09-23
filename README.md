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
git clone <YOUR-REPOSITORY-URL>
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

Create a `.env` file in the project directory and add the configuration
required by the agent, including your OpenAI API key.

Do not commit `.env` to GitHub.

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
git clone <YOUR-REPOSITORY-URL>
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

Create the local `.env` file and provide the required configuration,
including the OpenAI API key.

Do not commit `.env` or personal runtime data to GitHub.

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

For an always-on Linux or Raspberry Pi installation, the server can
optionally be configured as a `systemd` service.

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
git clone <YOUR-REPOSITORY-URL>
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

Create a `.env` file in the project directory and provide the required
configuration, including the OpenAI API key.

Do not upload this file to GitHub.

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
