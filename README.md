# 🖥️ DevOps Home Lab — Project 1: System Health Monitor
## A fully commented Bash script that monitors server health

### What This Project Is
A production-style system health monitoring script written in Bash. It reports on CPU usage, memory, disk space, network traffic, top processes, and service status. It saves every report to a dated log file.

### What You'll Learn
- Bash scripting fundamentals
- Linux system commands (top, free, df, ps, ip, systemctl)
- Reading from `/proc` — Linux's live system data filesystem
- Functions in Bash
- Conditional logic (if/else)
- Loops (while, for)
- Pipes and redirection
- Log file management
- Scheduled execution with cron

### How to Run It
```bash
# 1. Clone the repo
git clone https://github.com/Chippa88/devops-health-monitor.git
cd devops-health-monitor

# 2. Make the script executable
chmod +x monitor.sh

# 3. Run it
sudo ./monitor.sh

# 4. View the log
cat /var/log/health_monitor/health_$(date +%Y-%m-%d).log
```

### How to Schedule It (Cron)
```bash
# Open the cron editor
crontab -e

# Add this line to run every 5 minutes:
*/5 * * * * /path/to/monitor.sh >> /var/log/health_monitor/cron.log 2>&1

# Cron format: minute hour day month weekday command
# */5 = every 5 minutes
# * = any value for that field
```

### How to Study This
1. Read `monitor.sh` top to bottom. Every line has a comment explaining it.
2. Run it and see what the output looks like.
3. Change the `ALERT_THRESHOLD_CPU` to 10% and run it again — you'll see alerts.
4. Add a new section that you design yourself. Ideas:
   - Check if a specific port is open (using `netstat` or `ss`)
   - Count how many Docker containers are running
   - Check if a website is responding with `curl`

### Key Concepts This Project Teaches
| Concept | Where It Appears |
|---|---|
| Variables | `LOG_DIR`, `CPU_USAGE`, etc. |
| Functions | `print_header()`, `check_alert()` |
| Loops | `for service in...`, `while read` |
| Conditionals | `if [ "$STATUS" = "active" ]` |
| Command substitution | `$(date +%Y-%m-%d)` |
| Pipes | `top -bn1 \| grep \| awk` |
| File output | `tee -a "$LOG_FILE"` |
| Arithmetic | `awk "BEGIN {printf..."` |
