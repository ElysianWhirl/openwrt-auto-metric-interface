### README.md

```markdown
# OpenWrt Auto Metric Interface for Load Balance

A Bash script designed for OpenWrt routers that automates the adjustment of routing metrics for multiple network interfaces based on ping results. This script helps in load balancing and ensures optimal connectivity by dynamically setting metrics for interfaces such as USB and Ethernet.

## Features

- **Interface Monitoring:** Checks if interfaces are present and have an IP address.
- **Ping Testing:** Sends pings from specified interfaces to a target host.
- **Dynamic Metric Adjustment:** Adjusts routing metrics based on ping success or failure to facilitate load balancing.

## Getting Started

### Prerequisites

Ensure your OpenWrt router has:

- Bash shell support.
- Required utilities: `ping`, `ip`, `uci`.
- Permissions to modify network settings.

### Installation

1. **Clone the Repository:**

   SSH into your OpenWrt router and clone the repository:

   ```bash
   git clone https://github.com/ElysianWhirl/openwrt-auto-metric-interface.git /root/openwrt-auto-metric-interface
   cd /root/openwrt-auto-metric-interface
   ```

2. **Copy Script to Appropriate Location:**

   Move the script to the `/usr/bin/` directory or another directory included in your system's PATH for easier access:

   ```bash
   cp auto_metric.sh /usr/bin/auto_metric.sh
   chmod +x /usr/bin/auto_metric.sh
   ```

### Configuration

The script, `auto_metric.sh`, includes several variables that can be customized to match your network setup:

- **HOST:** The IP or domain name to ping for connectivity checks (default: `google.com`).
- **INTERVAL:** The time interval (in seconds) between ping checks (default: `3` seconds).
- **INTERFACES:** A list of network interfaces to monitor, e.g., `usb0 usb1 eth1`.
- **DEFAULT_METRICS:** The default routing metrics for each interface.
- **OFFLINE_METRICS:** The metrics set when an interface is considered offline.

Edit these values directly in the script as needed.

### Enabling on Startup

To ensure the script runs at startup, you can add it to the system's startup scripts:

1. **Create Startup Script:**

   Create a new init script in `/etc/init.d/`:

   ```bash
   vi /etc/init.d/auto_metric
   ```

2. **Script Contents:**

   Paste the following content into the file:

   ```bash
   #!/bin/sh /etc/rc.common
   # Copyright (C) 2006 OpenWrt.org

   START=99
   STOP=10

   start() {
       /usr/bin/auto_metric.sh &
   }

   stop() {
       killall auto_metric.sh
   }
   ```

3. **Make the Script Executable:**

   ```bash
   chmod +x /etc/init.d/auto_metric
   ```

4. **Enable the Script:**

   ```bash
   /etc/init.d/auto_metric enable
   ```

## Running the Script

To manually start the script, use:

```bash
/usr/bin/auto_metric.sh &
```

To stop the script, use:

```bash
killall auto_metric.sh
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
```

### Penjelasan Tambahan

- **Prasyarat:** Bagian ini menjelaskan apa saja yang perlu disiapkan sebelum menggunakan script, seperti utilitas yang harus tersedia.
- **Instalasi dan Konfigurasi:** Instruksi untuk menginstal dan mengonfigurasi script agar sesuai dengan kebutuhan spesifik.
- **Menjalankan pada Startup:** Langkah-langkah untuk memastikan script berjalan otomatis saat router dihidupkan.

Dengan mengikuti instruksi dalam README ini, script Anda akan terintegrasi dengan baik ke dalam sistem OpenWrt dan akan aktif setiap kali router di-restart.
