# MacUpdateGuard User Guide
**Control macOS system updates in three steps**

---

## 1. Download and Install
### Method 1: One-line install (Recommended)
Copy and paste this into Terminal:
```bash
cd ~ && \
curl -O https://raw.githubusercontent.com/ArdANANG/MacUpdateGuard/main/MacUpdateGuard.sh && \
chmod +x MacUpdateGuard.sh && \
sudo ./MacUpdateGuard.sh
```

### Method 2: Manual install
1. **Download the file**
   - Visit the [project homepage](https://github.com/ArdANANG/MacUpdateGuard)
   - Click the green `Code` button → `Download ZIP`

2. **Extract and move**
   ```bash
   # Open Terminal (Applications → Utilities → Terminal)
   mv ~/Downloads/MacUpdateGuard-main/MacUpdateGuard.sh ~/
   ```

3. **Grant execute permission**
   ```bash
   chmod +x ~/MacUpdateGuard.sh  # Make script executable
   ```

---

## 2. First-time Setup
1. Start the tool:
   ```bash
   sudo ~/MacUpdateGuard.sh  # Password required
   ```

2. Choose an installation option:
   ```
   [Prompt] Choose an action:
   1. Auto-install to user home and launch (recommended) → press 1
   2. Continue from current location
   3. Exit
   ```

> 💡 Choosing **1** completes final setup automatically.

---

## 3. Daily Usage
### Main menu features:
```
1. Disable automatic system updates  🚫
2. Restore automatic system updates  🔄
3. Check update status              📊
4. Show version information         ℹ️
5. Exit                             👋
```

### Quick command:
```bash
# Create a shortcut command (add to ~/.zshrc)
alias updateguard="sudo ~/MacUpdateGuard.sh"

# Then just run:
updateguard
```

---

## 4. Important Notes
1. **Restart is recommended after changes**
   - After disabling/restoring updates, choose "Restart now" for full effect.

2. **Update to the latest version**
   ```bash
   cd ~
   rm MacUpdateGuard.sh
   curl -O https://raw.githubusercontent.com/ArdANANG/MacUpdateGuard/main/MacUpdateGuard.sh
   chmod +x MacUpdateGuard.sh
   ```

3. **Check status regularly**
   - Use option 3 to review current system update status.
   - Open `System Settings > General > Software Update` to verify.

---

**Developer**: bili_25396444320
**Latest Version**: v4.2
**Last Updated**: March 5, 2026

> 🌟 Tip: After first launch, the script is saved in your home directory.
> Use `sudo ~/MacUpdateGuard.sh` anytime to manage macOS updates.
