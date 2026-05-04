#!/bin/bash
# ============================================================
# .claude/scripts/launch_for_testing.sh
#
# Launches the app in testing mode and extracts the VM Service URL.
# This prevents AI from hanging on compilation logs.
# ============================================================

echo "Starting Flutter in testing mode..."

# Ensure temp directory exists
mkdir -p .claude/tmp

# Get the device ID from the first argument (if provided by Claude)
DEVICE_ID=${1:-""}

if [ -n "$DEVICE_ID" ]; then
    echo "Launching on specific device: $DEVICE_ID"
    flutter run -d "$DEVICE_ID" > .claude/tmp/flutter_run.log &
else
    echo "Launching on default device..."
    flutter run > .claude/tmp/flutter_run.log &
fi

# Wait and extract the URL
echo "Waiting for VM Service URL..."
while true; do
    URL=$(grep -o "ws://127.0.0.1:[0-9]*/ws" .claude/tmp/flutter_run.log | head -1)
    if [ ! -z "$URL" ]; then
        echo "$URL" > .claude/tmp/vm_url.txt
        echo "✅ App running! VM Service URL saved to .claude/tmp/vm_url.txt"
        break
    fi
    sleep 2
done
