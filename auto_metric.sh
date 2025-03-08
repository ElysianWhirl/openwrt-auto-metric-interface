#!/bin/sh

# Host yang akan diping
HOST="your_host_for_ping"

# Interval waktu untuk melakukan ping (dalam detik)
INTERVAL=1

# Jumlah percobaan ping gagal sebelum mengubah metric
FAIL_THRESHOLD=3

# Daftar interface dan metric yang terkait
INTERFACES="usb0 usb1 eth1 macvlan"
DEFAULT_METRICS="4 2 3 1"
OFFLINE_METRICS="40 50 60 70"

# Fungsi untuk memeriksa apakah interface ada
check_interface_exists() {
    ip link show "$1" > /dev/null 2>&1
}

# Fungsi untuk memeriksa apakah interface memiliki IP
check_interface_ip() {
    ip addr show "$1" | grep -q "inet "
}

# Fungsi untuk ping dari interface tertentu
ping_from_interface() {
    local iface=$1
    if check_interface_exists "$iface" && check_interface_ip "$iface"; then
        ping -I "$iface" -c 1 -W 1 "$HOST" > /dev/null 2>&1
        return $?
    fi
    return 1
}

# Fungsi untuk mengatur metric untuk interface tertentu
set_metric_individual() {
    local iface=$1
    local metric=$2
    local current_metric
    
    # Ambil metric saat ini
    current_metric=$(uci get network.$iface.metric 2>/dev/null || echo "unknown")
    
    # Hanya atur jika metric berubah
    if [ "$current_metric" != "$metric" ]; then
        echo "Mengatur metric untuk $iface menjadi $metric"
        uci set network.$iface.metric="$metric" && \
        uci commit network && \
        /etc/init.d/network reload
    fi
}

# Status dan penghitung percobaan gagal untuk tiap interface
PREV_STATUS_USB0="UNKNOWN"
PREV_STATUS_USB1="UNKNOWN"
PREV_STATUS_ETH1="UNKNOWN"
PREV_STATUS_MACVLAN="UNKNOWN"

FAIL_COUNT_USB0=0
FAIL_COUNT_USB1=0
FAIL_COUNT_ETH1=0
FAIL_COUNT_MACVLAN=0

# Loop untuk memantau koneksi
while true; do
    i=1
    for iface in $INTERFACES; do
        default_metric=$(echo $DEFAULT_METRICS | cut -d ' ' -f $i)
        offline_metric=$(echo $OFFLINE_METRICS | cut -d ' ' -f $i)

        # Ping interface untuk cek status
        if ping_from_interface "$iface"; then
            # Update status dan reset fail count jika terhubung
            case "$iface" in
                usb0)
                    if [ "$PREV_STATUS_USB0" != "UP" ]; then
                        echo "$iface kembali UP, mengatur metric ke $default_metric"
                        set_metric_individual "$iface" "$default_metric"
                        PREV_STATUS_USB0="UP"
                    fi
                    FAIL_COUNT_USB0=0
                    ;;
                usb1)
                    if [ "$PREV_STATUS_USB1" != "UP" ]; then
                        echo "$iface kembali UP, mengatur metric ke $default_metric"
                        set_metric_individual "$iface" "$default_metric"
                        PREV_STATUS_USB1="UP"
                    fi
                    FAIL_COUNT_USB1=0
                    ;;
                eth1)
                    if [ "$PREV_STATUS_ETH1" != "UP" ]; then
                        echo "$iface kembali UP, mengatur metric ke $default_metric"
                        set_metric_individual "$iface" "$default_metric"
                        PREV_STATUS_ETH1="UP"
                    fi
                    FAIL_COUNT_ETH1=0
                    ;;
                macvlan)
                    if [ "$PREV_STATUS_MACVLAN" != "UP" ]; then
                        echo "$iface kembali UP, mengatur metric ke $default_metric"
                        set_metric_individual "$iface" "$default_metric"
                        PREV_STATUS_MACVLAN="UP"
                    fi
                    FAIL_COUNT_MACVLAN=0
                    ;;
            esac
        else
            # Menambah penghitung gagal jika masih gagal ping
            case "$iface" in
                usb0)
                    FAIL_COUNT_USB0=$((FAIL_COUNT_USB0 + 1))
                    if [ "$FAIL_COUNT_USB0" -ge "$FAIL_THRESHOLD" ]; then
                        if [ "$PREV_STATUS_USB0" != "DOWN" ]; then
                            echo "$iface DOWN setelah $FAIL_THRESHOLD percobaan gagal, mengatur metric ke $offline_metric"
                            set_metric_individual "$iface" "$offline_metric"
                            PREV_STATUS_USB0="DOWN"
                        fi
                    fi
                    ;;
                usb1)
                    FAIL_COUNT_USB1=$((FAIL_COUNT_USB1 + 1))
                    if [ "$FAIL_COUNT_USB1" -ge "$FAIL_THRESHOLD" ]; then
                        if [ "$PREV_STATUS_USB1" != "DOWN" ]; then
                            echo "$iface DOWN setelah $FAIL_THRESHOLD percobaan gagal, mengatur metric ke $offline_metric"
                            set_metric_individual "$iface" "$offline_metric"
                            PREV_STATUS_USB1="DOWN"
                        fi
                    fi
                    ;;
                eth1)
                    FAIL_COUNT_ETH1=$((FAIL_COUNT_ETH1 + 1))
                    if [ "$FAIL_COUNT_ETH1" -ge "$FAIL_THRESHOLD" ]; then
                        if [ "$PREV_STATUS_ETH1" != "DOWN" ]; then
                            echo "$iface DOWN setelah $FAIL_THRESHOLD percobaan gagal, mengatur metric ke $offline_metric"
                            set_metric_individual "$iface" "$offline_metric"
                            PREV_STATUS_ETH1="DOWN"
                        fi
                    fi
                    ;;
                macvlan)
                    FAIL_COUNT_MACVLAN=$((FAIL_COUNT_MACVLAN + 1))
                    if [ "$FAIL_COUNT_MACVLAN" -ge "$FAIL_THRESHOLD" ]; then
                        if [ "$PREV_STATUS_MACVLAN" != "DOWN" ]; then
                            echo "$iface DOWN setelah $FAIL_THRESHOLD percobaan gagal, mengatur metric ke $offline_metric"
                            set_metric_individual "$iface" "$offline_metric"
                            PREV_STATUS_MACVLAN="DOWN"
                        fi
                    fi
                    ;;
            esac
        fi
        i=$((i + 1))
    done
    sleep $INTERVAL
done
