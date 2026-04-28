#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=== OrpheusDL-GUI Termux Installer (VENV) ==="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$ROOT_DIR"
PROJECT_DIR="$ROOT_DIR"
PROJECT_FOLDER_NAME="${PROJECT_FOLDER_NAME:-OrpheusDL}"
REPO_ZIP_URL_MAIN="${REPO_ZIP_URL_MAIN:-https://github.com/bascurtiz/OrpheusDL-GUI/archive/refs/heads/main.zip}"
REPO_ZIP_URL_MASTER="${REPO_ZIP_URL_MASTER:-https://github.com/bascurtiz/OrpheusDL-GUI/archive/refs/heads/master.zip}"
TEMP_ZIP_PATH="$INSTALLER_DIR/orpheusdl-gui-latest.zip"
TEMP_EXTRACT_DIR="$INSTALLER_DIR/.orpheusdl_extract_tmp"
BOOTSTRAP_MODE="local"

bootstrap_project_if_needed() {
    if [ -f "$PROJECT_DIR/requirements.txt" ] && [ -f "$PROJECT_DIR/orpheus.py" ]; then
        return 0
    fi

    PROJECT_DIR="$INSTALLER_DIR/$PROJECT_FOLDER_NAME"
    if [ -f "$PROJECT_DIR/requirements.txt" ] && [ -f "$PROJECT_DIR/orpheus.py" ]; then
        echo "[*] Found existing project at: $PROJECT_DIR"
        BOOTSTRAP_MODE="existing-project-dir"
        return 0
    fi

    BOOTSTRAP_MODE="downloaded"
    echo ""
    echo "=== Installer-only mode detected ==="
    echo "[*] Project files were not found next to install_orpheus.sh."
    echo "[*] The installer will now bootstrap OrpheusDL automatically."
    echo "[*] Target folder: $PROJECT_DIR"
    echo ""
    echo "[*] Downloading OrpheusDL-GUI into: $PROJECT_DIR"

    rm -rf "$TEMP_EXTRACT_DIR"
    mkdir -p "$TEMP_EXTRACT_DIR"
    rm -f "$TEMP_ZIP_PATH"

    if ! curl -L --fail -o "$TEMP_ZIP_PATH" "$REPO_ZIP_URL_MAIN"; then
        echo "[*] main.zip unavailable, trying master.zip..."
        curl -L --fail -o "$TEMP_ZIP_PATH" "$REPO_ZIP_URL_MASTER"
    fi

    unzip -q "$TEMP_ZIP_PATH" -d "$TEMP_EXTRACT_DIR"
    EXTRACTED_DIR=""
    for candidate_dir in "$TEMP_EXTRACT_DIR"/*; do
        if [ -d "$candidate_dir" ]; then
            EXTRACTED_DIR="$candidate_dir"
            break
        fi
    done

    if [ -z "${EXTRACTED_DIR:-}" ] || [ ! -d "$EXTRACTED_DIR" ]; then
        echo "[!] Could not detect extracted repository directory."
        exit 1
    fi

    rm -rf "$PROJECT_DIR"
    mv "$EXTRACTED_DIR" "$PROJECT_DIR"
    rm -rf "$TEMP_EXTRACT_DIR"
    rm -f "$TEMP_ZIP_PATH"
}

bootstrap_project_if_needed
cd "$PROJECT_DIR"

# -------------------------------
# UPDATE & INSTALL BASE PACKAGES
# -------------------------------
echo "[*] Installing base packages..."
pkg update -y && pkg upgrade -y
pkg install -y python git libjpeg-turbo ffmpeg

# -------------------------------
# CREATE / ACTIVATE VENV
# -------------------------------
echo "[*] Creating virtual environment..."
python -m venv venv
source venv/bin/activate

# -------------------------------
# INSTALL REQUIREMENTS
# -------------------------------
echo "[*] Installing requirements..."
pip install --upgrade pip
pip install --upgrade --ignore-installed -r requirements.txt

if [ -f "requirements-gui.txt" ]; then
    pip install --upgrade --ignore-installed -r requirements-gui.txt
fi

# -------------------------------
# INITIAL SETUP
# -------------------------------
echo "[*] Running initial setup..."
python orpheus.py settings refresh || true
pip install --upgrade certifi

# -------------------------------
# INSTALL/UPDATE MODULES
# -------------------------------
echo "[*] Syncing modules..."
mkdir -p modules

clone_or_pull_module() {
    local repo_url="$1"
    local target_dir="$2"
    local clone_flags="${3:-}"

    if [ -d "$target_dir/.git" ]; then
        echo "    - updating $target_dir"
        git -C "$target_dir" pull --ff-only
    else
        echo "    - cloning $target_dir"
        git clone $clone_flags "$repo_url" "$target_dir"
    fi
}

clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-applemusic" "modules/applemusic"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-beatport" "modules/beatport"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-beatsource" "modules/beatsource"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-deezer" "modules/deezer"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-qobuz" "modules/qobuz"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-soundcloud" "modules/soundcloud"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-spotify" "modules/spotify"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-tidal" "modules/tidal" "--recurse-submodules"
clone_or_pull_module "https://github.com/bascurtiz/orpheusdl-youtube" "modules/youtube"

echo "[*] Installing module-specific requirements..."
for req_file in modules/*/requirements.txt; do
    if [ -f "$req_file" ]; then
        echo "    - $req_file"
        pip install --upgrade --ignore-installed -r "$req_file"
    fi
done

# -------------------------------
# TERMUX STORAGE
# -------------------------------
echo "[*] Setting up storage..."
termux-setup-storage || true

# -------------------------------
# FUTURE RUN INSTRUCTIONS
# -------------------------------
echo ""
echo "=== INSTALL COMPLETE ==="
if [ "$BOOTSTRAP_MODE" = "downloaded" ]; then
    echo "[*] Setup mode: installer-only bootstrap (downloaded project automatically)."
elif [ "$BOOTSTRAP_MODE" = "existing-project-dir" ]; then
    echo "[*] Setup mode: used existing project folder at $PROJECT_DIR."
else
    echo "[*] Setup mode: used local project files next to install_orpheus.sh."
fi
echo "Run CLI:"
echo "  cd \"$PROJECT_DIR\""
echo "  source venv/bin/activate"
echo "  python orpheus.py"
echo ""
echo "Run Desktop GUI:"
echo "  python gui.py"
echo ""
echo "Run Web UI (Flask):"
echo "  python webui.py"