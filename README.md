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

| Model | Series |
|-------|--------|
| MFC-J4510DW | Inkjet MFC |
| MFC-J4610DW | Inkjet MFC |
| MFC-J4710DW | Inkjet MFC |
| MFC-J5330DW | Inkjet MFC |
| MFC-J5340DW | Inkjet MFC |
| MFC-J5720DW | Inkjet MFC |
| MFC-J5730DW | Inkjet MFC |
| MFC-J5740DW | Inkjet MFC |
| MFC-J5910DW | Inkjet MFC |
| MFC-J5920DW | Inkjet MFC |
| MFC-J5930DW | Inkjet MFC |
| MFC-J5945DW | Inkjet MFC |
| MFC-J5955DW | Inkjet MFC |
| MFC-J6510DW | Inkjet MFC |
| MFC-J6530DW | Inkjet MFC |
| MFC-J6540DW | Inkjet MFC |
| MFC-J6555DW | Inkjet MFC |
| MFC-J6910DW | Inkjet MFC |
| MFC-J6920DW | Inkjet MFC |
| MFC-J6930DW | Inkjet MFC |
| MFC-J6935DW | Inkjet MFC |
| MFC-J6940DW | Inkjet MFC |
| MFC-J6945DW | Inkjet MFC |
| MFC-J6955DW | Inkjet MFC |
| MFC-L2710DW | Laser mono MFC |
| MFC-L2713DW | Laser mono MFC |
| MFC-L2730DW | Laser mono MFC |
| MFC-L2750DW | Laser mono MFC |
| MFC-L2770DW | Laser mono MFC |
| MFC-L2800DW | Laser mono MFC |
| MFC-L2820DW | Laser mono MFC |
| MFC-L2880DW | Laser mono MFC |
| MFC-L2900DW | Laser mono MFC |
| MFC-L2920DW | Laser mono MFC |
| MFC-L3750CDW | Laser colour MFC |
| MFC-L3770CDW | Laser colour MFC |
| MFC-L3720CDW | Laser colour MFC |
| MFC-L3760CDW | Laser colour MFC |
| MFC-L3780CDW | Laser colour MFC |
| MFC-9130CW | Laser colour MFC |
| MFC-9330CDW | Laser colour MFC |
| MFC-9340CDW | Laser colour MFC |
| DCP-L2530DW | Laser mono DCP |
| DCP-L2537DW | Laser mono DCP |
| DCP-L2550DW | Laser mono DCP |
| DCP-L2640DW | Laser mono DCP |
| DCP-L2680DW | Laser mono DCP |
| DCP-L3551CDW | Laser colour DCP |
| DCP-L3560CDW | Laser colour DCP |
| DCP-9020CDN | Laser colour DCP |
| HL-L2395DW | Laser mono HL |
| HL-L2464DW | Laser mono HL |
| HL-L2465DW | Laser mono HL |
| HL-L2480DW | Laser mono HL |
| HL-L3290CDW | Laser colour HL |
| HL-L3300CDW | Laser colour HL |
| HL-3180CDW | Laser colour HL |

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
