# OwnScan

**Your scans, straight to OwnCloud — self-hosted**

OwnScan bridges your Brother printer and OwnCloud. Scans are sent via FTP and automatically uploaded to OwnCloud.

![OwnScan logo](assets/logo.svg)

---

> ⚠️ **Local network only**
> OwnScan is designed for use on a **local network only**.
> Do **NOT** expose this to the internet. There is no HTTPS, no firewall, and no rate limiting.

---

## How it works

```
Brother printer → FTP → OwnScan server → OwnCloud
```

1. The Brother printer scans a document and sends it via FTP to the server running OwnScan.
2. OwnScan detects the new file and uploads it to OwnCloud via WebDAV (curl).
3. The local file is deleted after upload.
4. The scan appears in your OwnCloud folder.

## Requirements

- Debian or Ubuntu (LXC or VM)
- OwnCloud instance on the same local network
- Brother printer with **Scan to FTP** support (see supported printers below)

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/Linux-Ginger/ownscan/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/Linux-Ginger/ownscan
cd ownscan
chmod +x install.sh
bash install.sh
```

## Managing users

To add, edit or remove users after installation:

```bash
bash manage.sh
```

This opens an interactive menu where you can:
- View all users
- Add a new user
- Edit an existing user (FTP password, OwnCloud password, OwnCloud folder)
- Delete a user

## Uninstall

```bash
bash uninstall.sh
```

This opens an interactive uninstaller that removes all users, services, scripts and packages. Your OwnCloud files will not be deleted.

## Brother printer setup

After running the installer, configure your Brother printer via its web interface:

1. Go to `http://<printer-ip>` in your browser
2. Navigate to **Scan → Scan to FTP/Network profile**
3. Fill in:
   - **Host**: IP of your OwnScan server
   - **Username**: the FTP username you created
   - **Password**: the FTP password you created
   - **Directory**: `/`
   - **Port**: `21`
   - **Passive mode**: ON

## Supported printers

### Tested

| Model | Status |
|-------|--------|
| Brother MFC-J5320DW | ✅ Tested |
| Brother MFC-J6520DW | ✅ Tested |

### Should work (Scan to FTP supported, not tested)

Any Brother printer with Scan to FTP support should work. Models confirmed to have this feature include:

**MFC series (inkjet)**
- MFC-J5330DW, MFC-J5730DW, MFC-J5930DW, MFC-J5945DW
- MFC-J6530DW, MFC-J6930DW, MFC-J6935DW, MFC-J6945DW, MFC-J6947DW

**MFC series (laser, mono)**
- MFC-L2710DW, MFC-L2730DW, MFC-L2750DW, MFC-L2770DW
- MFC-L2800DW, MFC-L2820DW, MFC-L2880DW, MFC-L2900DW, MFC-L2920DW

**MFC series (laser, colour)**
- MFC-L3750CDW, MFC-L3770CDW
- MFC-L3720CDW, MFC-L3760CDW, MFC-L3780CDW
- MFC-9130CW, MFC-9330CDW, MFC-9340CDW

**DCP series**
- DCP-L2530DW, DCP-L2550DW, DCP-L2640DW, DCP-L2680DW
- DCP-L3551CDW, DCP-L3560CDW
- DCP-9020CDN

> If your model is not listed but has Scan to FTP, it will likely work. Feel free to open an issue or PR to add it to the list.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.

## Made by

[Linux Ginger](https://github.com/Linux-Ginger)
