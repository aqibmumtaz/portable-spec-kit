<!-- Section Version: v0.5.5 -->
### Python Environment (MANDATORY — Conda)
- **Every Python project MUST have its own conda environment** — never install packages into `base` or system Python
- **Default env name** = project directory name, lowercase, kebab-case (e.g., `aiiu`, `speech-ai-rd`, `my-api`)

#### Conda Installation (if not found)
Before any environment setup, verify conda is installed:
1. Check: `which conda` or `conda --version`
2. If not found → install Miniconda automatically:
   - **macOS:** `brew install --cask miniconda` (if Homebrew available) OR download from https://docs.conda.io/en/latest/miniconda.html
   - **Linux:** `wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && bash /tmp/miniconda.sh -b -p $HOME/miniconda3`
   - **Windows:** download installer from Miniconda website, ask user to run it
3. After install → initialize: `conda init zsh` (or `bash`)
4. Verify: `conda --version`
5. If automated install fails → tell user: "Conda is required. Install Miniconda from https://docs.conda.io/en/latest/miniconda.html and restart terminal."

#### Environment Selection (New Project + Existing Project Setup)
This flow runs in **two scenarios**:
- **New project setup** — when creating a new Python project from scratch
- **Existing project setup** — when installing the spec kit on an existing Python project (during the guided setup checklist)

In both cases, **always confirm with the user** before creating or selecting an environment:

1. List existing conda envs: `conda env list`
2. Ask the user:
   ```
   "This project needs a Python environment. Options:
   (a) Create new conda env '<project-name>' (recommended)
   (b) Use an existing env (select from list below)

   Existing envs:
     1. aiiu (Python 3.11)
     2. research (Python 3.10)
     3. speech-ai-rd (Python 3.9)
     ...

   Select (a/b or env name): "
   ```
3. **If (a) — Create new:**
   - Use default name `<project-name>` or let user type a custom name
   - Ask Python version: "Python version? (Enter = 3.11)" — default to 3.11
   - Create: `conda create -n <env-name> python=<version> -y`
   - If existing project has `requirements.txt` → install deps: `pip install -r requirements.txt`
4. **If (b) — Use existing:**
   - User picks from the list by number or name
   - Verify the env works: `conda run -n <env-name> python --version`
   - If existing project has `requirements.txt` → check if deps are installed, install missing ones
5. Record the chosen env name in `agent/AGENT.md` under Stack table (e.g., `Conda Env: aiiu`)

#### Edge Cases
- **Env name already exists** → ask user: "Env `<name>` already exists. Use it, or create with a different name?"
- **No existing envs** (only `base`) → skip option (b), go straight to create new
- **`requirements.txt` install fails** (version conflicts, missing packages) → show error, ask user to resolve. Don't silently skip failed installs
- **Project uses `pyproject.toml` or `setup.py` instead of `requirements.txt`** → use `pip install -e .` or `pip install .` as appropriate
- **Project uses `environment.yml`** (conda env file) → ask user: "Found environment.yml. Create env from it? (`conda env create -f environment.yml`)" — this takes priority over `requirements.txt`
- **User has `venv`/`virtualenv` already in the project** → ask: "Found existing venv at `<path>`. Switch to conda env, or keep venv?" — respect user's choice. If keeping venv, record it in AGENT.md and skip conda setup
- **Python version mismatch** → existing env has Python 3.9 but project needs 3.11 (e.g., from `pyproject.toml` or `runtime.txt`) → warn user before proceeding
- **Env recorded in AGENT.md but doesn't exist on disk** → re-run environment selection flow, don't auto-create silently
- **Multiple Python projects in monorepo** → each subdirectory project can have its own env. Ask per project, don't assume one env for all

#### On Every Session
- Activate the project's conda env before running any Python commands
- Check `agent/AGENT.md` for the env name if unsure
- If env was deleted or missing → re-run the environment selection flow above

#### Rules
- **All `pip install` commands** must run inside the project's conda env — never use `--break-system-packages` or install globally
- **`requirements.txt`** must be maintained at project root — update after every `pip install`:
  ```bash
  pip freeze > requirements.txt
  ```
- **Shebang lines** in Python scripts: use `#!/usr/bin/env python3` (relies on active conda env, not hardcoded paths)
- **`.gitignore`** should include conda env artifacts but NOT `requirements.txt` (commit it)
- **Never hardcode** conda env paths in scripts — use `#!/usr/bin/env python3` or `conda run -n <env>`

