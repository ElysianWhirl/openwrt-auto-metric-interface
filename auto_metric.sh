#!/bin/sh

# Host yang akan diping
HOSTS="host1 host2"

# Interval waktu untuk melakukan ping (dalam detik)
INTERVAL=1

# Jumlah percobaan ping gagal sebelum mengubah metric
FAIL_THRESHOLD=3

# Daftar interface dan metric yang terkait
INTERFACES="macvlan eth2"
DEFAULT_METRICS="1 5"
OFFLINE_METRICS="60 70"

# Fungsi untuk memeriksa apakah interface ada
check_interface_exists() {
    ip link show "$1" > /dev/null 2>&1
}

# Fungsi untuk memeriksa apakah interface memiliki IP
check_interface_ip() {
    ip addr show "$1" | grep -q "inet "
}

# Fungsi untuk ping dari interface tertentu ke semua host
ping_from_interface() {
    local iface=$1
    if check_interface_exists "$iface" && check_interface_ip "$iface"; then
        for host in $HOSTS; do
            if ping -I "$iface" -c 3 -W 1 "$host" > /dev/null 2>&1; then
                return 0  # Jika salah satu host bisa di-ping, kembalikan sukses
            fi
        done
    fi
    return 1  # Jika semua host gagal di-ping, kembalikan gagal
}

# Fungsi untuk mengatur metric untuk interface tertentu
set_metric_individual() {
    local iface=$1
    local metric=$2
    local current_metric
    
    current_metric=$(uci get network.$iface.metric 2>/dev/null || echo "unknown")
    
    if [ "$current_metric" != "$metric" ]; then
        echo "Mengatur metric untuk $iface menjadi $metric"
        uci set network.$iface.metric="$metric" && \
        uci commit network && \
        /etc/init.d/network reload
    fi
}

# Inisialisasi status dan penghitung percobaan gagal untuk tiap interface
eval "$(for iface in $INTERFACES; do echo "PREV_STATUS_$iface=UNKNOWN"; echo "FAIL_COUNT_$iface=0"; done)"

# Loop untuk memantau koneksi
while true; do
    i=1
    for iface in $INTERFACES; do
        default_metric=$(echo $DEFAULT_METRICS | cut -d ' ' -f $i)
        offline_metric=$(echo $OFFLINE_METRICS | cut -d ' ' -f $i)

        if ping_from_interface "$iface"; then
            eval "current_status=\$PREV_STATUS_$iface"
            if [ "$current_status" != "UP" ]; then
                echo "$iface kembali UP, mengatur metric ke $default_metric"
                set_metric_individual "$iface" "$default_metric"
                eval "PREV_STATUS_$iface=UP"
            fi
            eval "FAIL_COUNT_$iface=0"
        else
            eval "FAIL_COUNT_$iface=\$((FAIL_COUNT_$iface + 1))"
            eval "fail_count=\$FAIL_COUNT_$iface"
            if [ "$fail_count" -ge "$FAIL_THRESHOLD" ]; then
                eval "current_status=\$PREV_STATUS_$iface"
                if [ "$current_status" != "DOWN" ]; then
                    echo "$iface DOWN setelah $FAIL_THRESHOLD percobaan gagal, mengatur metric ke $offline_metric"
                    set_metric_individual "$iface" "$offline_metric"
                    eval "PREV_STATUS_$iface=DOWN"
                fi
            fi
        fi
        i=$((i + 1))
    done
    sleep $INTERVAL
done
