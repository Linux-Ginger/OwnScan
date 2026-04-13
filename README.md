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
Brother printer → FTP → OwnScan (LXC/server) → OwnCloud
```

1. The Brother printer scans a document and sends it via FTP to the server running OwnScan.
2. OwnScan detects the new file and uploads it to OwnCloud via WebDAV (curl).
3. The local file is deleted after upload.
4. The scan appears in your OwnCloud folder.

## Requirements

- Debian or Ubuntu (LXC or VM)
- OwnCloud instance on the same local network
- Brother printer with **Scan to FTP** support (tested on MFC-J5320DW, MFC-J6520DW)

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

## Uninstall

```bash
bash uninstall.sh
```

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

Any Brother printer with **Scan to FTP** support should work.

Tested on:
- Brother MFC-J5320DW ✓
- Brother MFC-J6520DW (untested, should work)

## License

MIT License — free to use, modify and distribute.

## Made by

[Linux Ginger](https://github.com/Linux-Ginger)
