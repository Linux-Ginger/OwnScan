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

- Debian or Ubuntu
- OwnCloud instance on the same local network
- Brother printer with **Scan to FTP** support (see supported printers below)

## Supported printers

### Tested

| Model | Status |
|-------|--------|
| Brother MFC-J5320DW | ✅ Tested |
| Brother MFC-J6520DW | ✅ Tested |

### Not tested — should work

These models are confirmed to support Scan to FTP based on official Brother documentation.

**MFC inkjet**

| Model |
|-------|
| MFC-J4510DW |
| MFC-J4610DW |
| MFC-J4710DW |
| MFC-J5330DW |
| MFC-J5340DW |
| MFC-J5720DW |
| MFC-J5730DW |
| MFC-J5740DW |
| MFC-J5910DW |
| MFC-J5920DW |
| MFC-J5930DW |
| MFC-J5945DW |
| MFC-J5955DW |
| MFC-J6510DW |
| MFC-J6530DW |
| MFC-J6540DW |
| MFC-J6555DW |
| MFC-J6910DW |
| MFC-J6920DW |
| MFC-J6930DW |
| MFC-J6935DW |
| MFC-J6940DW |
| MFC-J6945DW |
| MFC-J6955DW |

**Laser mono MFC**

| Model |
|-------|
| MFC-L2710DW |
| MFC-L2713DW |
| MFC-L2730DW |
| MFC-L2750DW |
| MFC-L2770DW |
| MFC-L2800DW |
| MFC-L2820DW |
| MFC-L2880DW |
| MFC-L2900DW |
| MFC-L2920DW |

**Laser colour MFC**

| Model |
|-------|
| MFC-L3720CDW |
| MFC-L3750CDW |
| MFC-L3760CDW |
| MFC-L3770CDW |
| MFC-L3780CDW |
| MFC-9130CW |
| MFC-9330CDW |
| MFC-9340CDW |

**Laser mono DCP**

| Model |
|-------|
| DCP-L2530DW |
| DCP-L2537DW |
| DCP-L2550DW |
| DCP-L2640DW |
| DCP-L2680DW |

**Laser colour DCP**

| Model |
|-------|
| DCP-L3551CDW |
| DCP-L3560CDW |
| DCP-9020CDN |

**Laser mono HL**

| Model |
|-------|
| HL-L2395DW |
| HL-L2464DW |
| HL-L2465DW |
| HL-L2480DW |

**Laser colour HL**

| Model |
|-------|
| HL-L3290CDW |
| HL-L3300CDW |
| HL-3180CDW |

> This list is based on official Brother documentation. If your model has Scan to FTP, it will work with OwnScan.

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/Linux-Ginger/ownscan/main/install.sh | bash
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

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.

---

Made with ❤️ by [Linux Ginger](https://github.com/Linux-Ginger)
