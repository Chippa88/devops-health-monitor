#!/bin/bash
# ============================================================
# SYSTEM HEALTH MONITOR
# Author: Chip Sineath | DevOps Home Lab Project #1
# GitHub: github.com/Chippa88/devops-health-monitor
# ============================================================
# WHAT THIS SCRIPT DOES:
#   This script checks the health of a Linux server every time
#   it runs. It looks at CPU usage, memory usage, disk space,
#   and the top running processes. It then writes everything
#   to a log file AND prints it to the terminal.
#
#   In the real world, this type of script runs automatically
#   on a schedule (called a "cron job") — every 5 minutes,
#   every hour, etc. — so you always have a record of your
#   server's health over time.
# ============================================================

# ── CONFIGURATION ──────────────────────────────────────────
# These are variables. In bash, a variable stores a value you
# can reuse throughout the script. Think of it like a labeled box.

# LOG_DIR: The folder where we'll save our log files.
# The $ sign before a variable name means "use the value inside this box"
LOG_DIR="/var/log/health_monitor"

# LOG_FILE: The full path to today's log file.
# $(date +%Y-%m-%d) runs the 'date' command and inserts the result inline.
# So if today is April 14, 2026, LOG_FILE becomes:
#   /var/log/health_monitor/health_2026-04-14.log
LOG_FILE="$LOG_DIR/health_$(date +%Y-%m-%d).log"

# ALERT_THRESHOLD_CPU: If CPU usage is ABOVE this number (%), we flag it.
ALERT_THRESHOLD_CPU=85

# ALERT_THRESHOLD_MEM: If memory usage is ABOVE this number (%), we flag it.
ALERT_THRESHOLD_MEM=85

# ALERT_THRESHOLD_DISK: If disk usage is ABOVE this number (%), we flag it.
ALERT_THRESHOLD_DISK=90

# ── SETUP ──────────────────────────────────────────────────
# mkdir: "make directory" — creates a folder if it doesn't exist
# -p: means "create parent directories too if needed, and don't error if it already exists"
mkdir -p "$LOG_DIR"

# ── HELPER FUNCTION: print_header ─────────────────────────
# A "function" is a reusable block of code. You define it once,
# then call it by name anywhere in the script.
# This function prints a formatted section header to both the
# terminal AND the log file.
print_header() {
    # $1 is the first argument passed to this function.
    # When we call: print_header "CPU USAGE"
    # Inside the function, $1 = "CPU USAGE"
    local title="$1"

    # 'echo' prints text. The \n is a newline character (line break).
    # The | (pipe) sends the output of echo INTO the next command.
    # tee: takes input and sends it to BOTH a file AND the terminal at the same time.
    # -a: "append" — don't overwrite the file, add to the end of it.
    echo -e "\n========================================" | tee -a "$LOG_FILE"
    echo "  $title" | tee -a "$LOG_FILE"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
}

# ── HELPER FUNCTION: check_alert ──────────────────────────
# This function compares a value against a threshold.
# If the value EXCEEDS the threshold, it prints a WARNING.
# Arguments:
#   $1 = the label (e.g. "CPU")
#   $2 = the current value (e.g. 92)
#   $3 = the threshold (e.g. 85)
check_alert() {
    local label="$1"
    local value="$2"
    local threshold="$3"

    # The 'if' statement runs code conditionally.
    # $((...)) is arithmetic evaluation — math inside bash.
    # -gt means "greater than"
    # So this reads: "if value is greater than threshold, then..."
    if [ "$(echo "$value > $threshold" | bc -l)" -eq 1 ] 2>/dev/null || [ "${value%.*}" -gt "$threshold" ] 2>/dev/null; then
        echo "⚠️  ALERT: $label is at ${value}% (threshold: ${threshold}%)" | tee -a "$LOG_FILE"
    fi
}

# ── SECTION 1: TIMESTAMP ──────────────────────────────────
# Every log entry needs a timestamp so you know WHEN it ran.
echo "" | tee -a "$LOG_FILE"
echo "╔══════════════════════════════════════════╗" | tee -a "$LOG_FILE"
echo "║       SYSTEM HEALTH MONITOR REPORT      ║" | tee -a "$LOG_FILE"
echo "║   $(date '+%Y-%m-%d %H:%M:%S')              ║" | tee -a "$LOG_FILE"
echo "╚══════════════════════════════════════════╝" | tee -a "$LOG_FILE"

# ── SECTION 2: SYSTEM INFO ────────────────────────────────
print_header "SYSTEM INFORMATION"

# hostname: prints the name of this computer/server on the network
echo "Hostname    : $(hostname)" | tee -a "$LOG_FILE"

# uname -r: prints the Linux kernel version currently running
echo "Kernel      : $(uname -r)" | tee -a "$LOG_FILE"

# uptime -p: prints how long the system has been running since last reboot
# Example output: "up 3 days, 4 hours, 22 minutes"
echo "Uptime      : $(uptime -p)" | tee -a "$LOG_FILE"

# who -q: lists all users currently logged into the system
echo "Logged In   : $(who -q | head -1)" | tee -a "$LOG_FILE"

# ── SECTION 3: CPU USAGE ──────────────────────────────────
print_header "CPU USAGE"

# This is a multi-step command chain. Let's break it down:
# top -bn1: runs the 'top' command (task manager) in batch mode (-b) for 1 iteration (-n1)
# grep "Cpu(s)": filters for only the line containing "Cpu(s)"
# awk '{print $2}': prints the 2nd "word" on that line (the CPU usage %)
# sed 's/%us,//': removes the "%us," text, leaving just the number
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | tr -d ' ')

# If top format varies by system, fall back to /proc/stat calculation
# /proc/stat is a special Linux file that contains raw CPU statistics
if [ -z "$CPU_USAGE" ]; then
    # Read two snapshots of CPU stats, 1 second apart, to calculate usage %
    CPU_LINE1=$(cat /proc/stat | grep "^cpu " | awk '{print $2,$3,$4,$5,$6,$7,$8}')
    sleep 1
    CPU_LINE2=$(cat /proc/stat | grep "^cpu " | awk '{print $2,$3,$4,$5,$6,$7,$8}')
    
    # Parse the values using awk (a text processing tool)
    CPU_USAGE=$(echo "$CPU_LINE1 $CPU_LINE2" | awk '{
        idle1=$4; total1=$1+$2+$3+$4+$5+$6+$7
        idle2=$11; total2=$8+$9+$10+$11+$12+$13+$14
        diff_idle=idle2-idle1
        diff_total=total2-total1
        diff_usage=(1000*(diff_total-diff_idle)/diff_total+5)/10
        printf "%.1f", diff_usage
    }')
fi

echo "CPU Usage   : ${CPU_USAGE}%" | tee -a "$LOG_FILE"

# mpstat shows CPU usage per core — great for multi-core systems
# 2>/dev/null suppresses error messages if mpstat isn't installed
mpstat 1 1 2>/dev/null | grep "Average" | awk '{printf "  Idle: %.1f%% | User: %.1f%% | System: %.1f%%\n", $12, $3, $5}' | tee -a "$LOG_FILE"

# Check if CPU is over threshold
check_alert "CPU" "${CPU_USAGE%.*}" "$ALERT_THRESHOLD_CPU"

# ── SECTION 4: MEMORY USAGE ───────────────────────────────
print_header "MEMORY USAGE"

# free -m: shows memory info in megabytes
# grep "^Mem:": finds the line starting with "Mem:"
# awk: extracts specific columns
#   $2 = total memory
#   $3 = used memory  
#   $4 = free memory
#   $7 = available memory (the real "free" — accounts for cache)
MEM_TOTAL=$(free -m | grep "^Mem:" | awk '{print $2}')
MEM_USED=$(free -m | grep "^Mem:" | awk '{print $3}')
MEM_FREE=$(free -m | grep "^Mem:" | awk '{print $4}')
MEM_AVAILABLE=$(free -m | grep "^Mem:" | awk '{print $7}')

# Calculate memory usage percentage using awk arithmetic
# printf "%.1f" formats the number to 1 decimal place
MEM_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($MEM_USED/$MEM_TOTAL)*100}")

echo "Total RAM   : ${MEM_TOTAL} MB" | tee -a "$LOG_FILE"
echo "Used        : ${MEM_USED} MB (${MEM_PERCENT}%)" | tee -a "$LOG_FILE"
echo "Free        : ${MEM_FREE} MB" | tee -a "$LOG_FILE"
echo "Available   : ${MEM_AVAILABLE} MB" | tee -a "$LOG_FILE"

# Also show swap usage (swap is disk space used as emergency RAM)
SWAP_TOTAL=$(free -m | grep "^Swap:" | awk '{print $2}')
SWAP_USED=$(free -m | grep "^Swap:" | awk '{print $3}')
echo "Swap Used   : ${SWAP_USED} MB / ${SWAP_TOTAL} MB" | tee -a "$LOG_FILE"

check_alert "Memory" "${MEM_PERCENT%.*}" "$ALERT_THRESHOLD_MEM"

# ── SECTION 5: DISK USAGE ─────────────────────────────────
print_header "DISK USAGE"

# df -h: "disk free" — shows all mounted filesystems
#   -h: "human readable" (shows GB/MB instead of raw bytes)
# grep -v: -v means "invert" — show lines that do NOT match this pattern
#   We're filtering out tmpfs (temporary memory filesystems) and udev
# We then loop through each real disk partition and report on it
echo "Filesystem usage:" | tee -a "$LOG_FILE"

# This 'while read' loop processes each line of output from df
# IFS (Internal Field Separator) splits the line into variables
df -h | grep -v "^tmpfs\|^udev\|^Filesystem" | while IFS= read -r line; do
    # Extract the usage percentage (the column that ends in %)
    usage_percent=$(echo "$line" | awk '{print $5}' | tr -d '%')
    filesystem=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    mount=$(echo "$line" | awk '{print $6}')

    # Only report on real filesystems (mounted paths starting with /)
    if [[ "$mount" == /* ]]; then
        echo "  $mount: ${used} used of ${size} (${usage_percent}%)" | tee -a "$LOG_FILE"
        check_alert "Disk ($mount)" "$usage_percent" "$ALERT_THRESHOLD_DISK"
    fi
done

# ── SECTION 6: NETWORK STATISTICS ────────────────────────
print_header "NETWORK STATISTICS"

# ip addr: shows all network interfaces and their IP addresses
# grep "inet ": finds lines with IPv4 addresses (not IPv6 which is "inet6")
# grep -v "127.0.0.1": excludes loopback (localhost — not a real network interface)
echo "IP Addresses:" | tee -a "$LOG_FILE"
ip addr | grep "inet " | grep -v "127.0.0.1" | awk '{print "  " $NF ": " $2}' | tee -a "$LOG_FILE"

# /proc/net/dev: a special file that contains network traffic statistics
# We extract bytes received (RX) and transmitted (TX) for the main interface
echo "" | tee -a "$LOG_FILE"
echo "Network Traffic (since boot):" | tee -a "$LOG_FILE"
cat /proc/net/dev | grep -v "lo:" | grep ":" | while IFS= read -r line; do
    interface=$(echo "$line" | awk -F: '{print $1}' | tr -d ' ')
    rx_bytes=$(echo "$line" | awk '{print $2}')
    tx_bytes=$(echo "$line" | awk '{print $10}')
    if [ -n "$rx_bytes" ] && [ "$rx_bytes" -gt 0 ] 2>/dev/null; then
        # Convert bytes to MB for readability
        rx_mb=$(awk "BEGIN {printf \"%.2f\", $rx_bytes/1048576}")
        tx_mb=$(awk "BEGIN {printf \"%.2f\", $tx_bytes/1048576}")
        echo "  $interface — RX: ${rx_mb} MB | TX: ${tx_mb} MB" | tee -a "$LOG_FILE"
    fi
done

# ── SECTION 7: TOP PROCESSES ──────────────────────────────
print_header "TOP 10 PROCESSES BY CPU"

# ps aux: list all running processes with details
#   a = all users
#   u = show user/owner
#   x = include processes not attached to a terminal
# sort -rk3: sort in reverse (-r) by column 3 (-k3) which is CPU usage
# head -11: take the first 11 lines (1 header + top 10 processes)
echo "USER         PID   CPU%  MEM%  COMMAND" | tee -a "$LOG_FILE"
ps aux --sort=-%cpu | head -11 | tail -10 | awk '{printf "%-12s %-6s %-6s %-6s %s\n", $1, $2, $3, $4, $11}' | tee -a "$LOG_FILE"

print_header "TOP 10 PROCESSES BY MEMORY"
echo "USER         PID   CPU%  MEM%  COMMAND" | tee -a "$LOG_FILE"
ps aux --sort=-%mem | head -11 | tail -10 | awk '{printf "%-12s %-6s %-6s %-6s %s\n", $1, $2, $3, $4, $11}' | tee -a "$LOG_FILE"

# ── SECTION 8: SERVICES STATUS ────────────────────────────
print_header "CRITICAL SERVICES STATUS"

# Define an array of services we want to monitor
# An array in bash is a list of items: ARRAY=("item1" "item2" "item3")
SERVICES=("ssh" "cron" "nginx" "docker" "ufw")

# Loop through each service in the array
# 'for service in "${SERVICES[@]}"' = "for each item in the array"
for service in "${SERVICES[@]}"; do
    # systemctl is-active: checks if a service is currently running
    # Returns "active" or "inactive" or "failed"
    STATUS=$(systemctl is-active "$service" 2>/dev/null)
    
    # Use a conditional to set an emoji based on status
    if [ "$STATUS" = "active" ]; then
        STATUS_ICON="✅"
    elif [ "$STATUS" = "inactive" ]; then
        STATUS_ICON="⚪"
    else
        STATUS_ICON="❌"
    fi
    
    printf "  %s %-20s %s\n" "$STATUS_ICON" "$service" "$STATUS" | tee -a "$LOG_FILE"
done

# ── FOOTER ────────────────────────────────────────────────
echo "" | tee -a "$LOG_FILE"
echo "════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "  Report complete. Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "  Run 'cat $LOG_FILE' to review anytime." | tee -a "$LOG_FILE"
echo "════════════════════════════════════════════" | tee -a "$LOG_FILE"
