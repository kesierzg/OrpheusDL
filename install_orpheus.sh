#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=== OrpheusDL-GUI Termux Installer (VENV) ==="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

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
echo "Run CLI:"
echo "  cd \"$ROOT_DIR\""
echo "  source venv/bin/activate"
echo "  python orpheus.py"
echo ""
echo "Run Desktop GUI:"
echo "  python gui.py"
echo ""
echo "Run Web UI (Flask):"
echo "  python webui.py"