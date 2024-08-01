#!/bin/sh

# Host yang akan diping
HOST="google.com"

# Interval waktu untuk melakukan ping (dalam detik)
INTERVAL=3

# Daftar interface dan metric yang terkait
INTERFACES="usb0 usb1 eth1"
DEFAULT_METRICS="1 2 3"
OFFLINE_METRICS="40 50 60"

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
    local host=$2
    if check_interface_exists $iface && check_interface_ip $iface; then
        ping -I $iface -c 1 $host > /dev/null 2>&1
        return $?
    else
        if ! check_interface_exists $iface; then
            echo "Interface $iface tidak ada"
        elif ! check_interface_ip $iface; then
            echo "Interface $iface tidak memiliki IP"
        fi
        return 1
    fi
}

# Fungsi untuk mengatur metric untuk interface tertentu
set_metric_individual() {
    local iface=$1
    local metric=$2
    echo "Mengatur metric untuk $iface menjadi $metric"
    uci set network.$iface.metric="$metric" && \
    uci commit network && \
    /etc/init.d/network reload
    if [ $? -ne 0 ]; then
        echo "Gagal mengatur metric untuk $iface"
    fi
}

# Counter keberhasilan ping untuk masing-masing interface
SUCCESS_COUNT_usb0=0
SUCCESS_COUNT_usb1=0
SUCCESS_COUNT_eth1=0

# Counter kegagalan ping untuk masing-masing interface
FAIL_COUNT_usb0=0
FAIL_COUNT_usb1=0
FAIL_COUNT_eth1=0

# Loop untuk memantau koneksi
while true; do
    # Iterasi melalui interface
    i=1
    for iface in $INTERFACES; do
        eval "success_count=\$SUCCESS_COUNT_$iface"
        eval "fail_count=\$FAIL_COUNT_$iface"
        default_metric=$(echo $DEFAULT_METRICS | cut -d ' ' -f $i)
        offline_metric=$(echo $OFFLINE_METRICS | cut -d ' ' -f $i)
        echo "Pinging dari $iface..."
        
        if ping_from_interface $iface $HOST; then
            echo "Ping berhasil dari $iface"
            fail_count=0
            success_count=$((success_count+1))
            # Set kembali metric default jika sukses 3x berturut-turut
            if [ $success_count -ge 3 ]; then
                set_metric_individual $iface $default_metric
                success_count=0  # Reset hitungan sukses setelah perubahan
            fi
        else
            echo "Ping gagal dari $iface"
            success_count=0
            fail_count=$((fail_count+1))
            # Set metric offline jika terjadi kegagalan 3x berturut-turut
            if [ $fail_count -ge 3 ]; then
                set_metric_individual $iface $offline_metric
                fail_count=0  # Reset hitungan gagal setelah perubahan
            fi
        fi

        eval "SUCCESS_COUNT_$iface=$success_count"
        eval "FAIL_COUNT_$iface=$fail_count"
        i=$((i + 1))
    done

    # Tunggu sebelum melakukan ping lagi
    sleep $INTERVAL
done
