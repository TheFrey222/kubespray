#!/usr/bin/env bash
set -euo pipefail

FILE="inventory/robot/inventory.ini"

# Get the current primary IPv4 (based on default route), fallback to first hostname -I
CURRENT_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
if [[ -z "${CURRENT_IP:-}" ]]; then
  CURRENT_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi

if [[ -z "${CURRENT_IP:-}" ]]; then
  echo "Could not determine current IP address." >&2
  exit 1
fi

echo "Detected current IP: ${CURRENT_IP}"

# Backup
BACKUP="${FILE}.bak.$(date +%F_%H%M%S)"
cp -f "$FILE" "$BACKUP"
echo "Backup created at: $BACKUP"

# Replace values after ansible_host= and ip= (token-safe, not assuming IPv4 format in file)
awk -v newip="$CURRENT_IP" '
BEGIN{FS=OFS=" "}
{
  for (i=1; i<=NF; i++) {
    if ($i ~ /^ansible_host=/) sub(/=.*/, "=" newip, $i)
    if ($i ~ /^ip=/)           sub(/=.*/, "=" newip, $i)
  }
  print
}' "$BACKUP" > "$FILE"

echo "Updated ${FILE} with IP ${CURRENT_IP}"
echo
echo "Preview of the updated line(s):"
grep -nE 'ansible_host=|(^|[[:space:]])ip=' "$FILE" || true

echo "Removing backup file"
rm -f "$BACKUP"