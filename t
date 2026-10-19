#!/bin/bash

set -e

# Network
IFACE="enp0s31f6"
PC_IP="192.168.168.42"
PC_CIDR="$PC_IP/24"
IOLAN_IP="192.168.168.35"

# Application
APP="middleman"
TFTP_ROOT="/srv/tftp"

# IOLAN credentials
IOLAN_USER="admin"
IOLAN_PASS="superuser"


# Configure client ethernet
echo "==> Configuring Ethernet..."
sudo ip addr flush dev "$IFACE"
sudo ip addr add "$PC_CIDR" dev "$IFACE"
sudo ip link set "$IFACE" up

# Build Executable if needed
echo "==> Building $APP..."
make -f m

# Copy executable to TFTP server
echo "==> Copying $APP to TFTP root..."
cp "./$APP" "$TFTP_ROOT/$APP"

echo "==> Restarting TFTP server..."

# Ensure sudo credentials are available before starting a background process.
sudo -v

# Stop any existing in.tftpd processes.
if pgrep -x in.tftpd >/dev/null; then
    sudo pkill -x in.tftpd
    sleep 1
fi

# Start the server and capture startup errors.
sudo /usr/bin/in.tftpd --foreground --ipv4 --secure "$TFTP_ROOT" \
    >/tmp/iolan-tftp.log 2>&1 &
TFTP_PID=$!

sleep 1

if ! pgrep -x in.tftpd >/dev/null; then
    echo "ERROR: TFTP server is not running."
    cat /tmp/iolan-tftp.log
    exit 1
fi

echo "==> TFTP server is running."

sleep 1

echo "==> Connecting to IOLAN at $IOLAN_IP..."

export IOLAN_IP IOLAN_USER IOLAN_PASS PC_IP APP

expect <<'EOF'
set timeout 30

spawn telnet $env(IOLAN_IP)

expect "Login:"
send "$env(IOLAN_USER)\r"

expect "Password:"
send "$env(IOLAN_PASS)\r"

expect "DG1#"

# Upload new executable
puts "==> Uploading new middleman..."
send "netload customapp-file $env(PC_IP) $env(APP)\r"
expect "DG1#"

# =====================================================================================================
puts "==> Finding current middleman PID..."

# Send the command and wait for the next prompt.
send "shell ps | grep '/sdk/middleman' | grep -v 'grep'\r"
expect {
    -re {DG1#\s*$} {
        set output $expect_out(buffer)
    }
    timeout {
        puts "ERROR: Timed out waiting for process list"
        exit 1
    }
}

# Extract the PID from the matching process line.
if {[regexp -line {^\s*([0-9]+)\s+root\s+.*\/sdk/middleman\s*$} $output -> pid]} {
    puts "==> Current middleman PID: $pid"
} else {
    puts "ERROR: Could not extract middleman PID"
    puts "Captured output: $output"
    exit 1
}

if {$pid eq ""} {
    puts "ERROR: Could not find middleman PID"
    puts "Captured output: [list $output]"
    exit 1
}

# Kill middleman and let supervisor respawn it ================================================
puts "==> Restarting middleman..."
send "shell kill $pid\r"
expect "DG1#"

# Wait for supervisor to respawn it
after 1000

# Verify new middleman with new PID spawned ===================================================
puts "==> Verifying middleman..."

send "shell ps | grep '/sdk/middleman' | grep -v 'grep'\r"
expect {
    -re {DG1#\s*$} {
        set output $expect_out(buffer)
    }
    timeout {
        puts "ERROR: Timed out waiting for process list"
        exit 1
    }
}

# Extract the PID from the matching process line.
if {[regexp -line {^\s*([0-9]+)\s+root\s+.*\/sdk/middleman\s*$} $output -> newpid]} {
    puts "==> Current middleman PID: $newpid"
} else {
    puts "ERROR: Could not extract middleman PID"
    puts "Captured output: $output"
    exit 1
}

if {$newpid != $pid} {
    puts "==> Middleman Successfully restarted"
}

# ============================================================================================

send "logout\r"
expect eof
EOF

echo "==> Deployment complete."