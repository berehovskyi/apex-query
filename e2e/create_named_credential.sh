#!/bin/bash

# Usage: ./e2e/create_named_credential.sh
#        ./e2e/create_named_credential.sh --org <alias>
# This script replaces placeholders in e2e/main/ files and deploys the folder.

set -e

SOURCE_DIR="e2e/main/soql-external"
BACKUP_DIR="e2e/.backups"
NC_FILE="$SOURCE_DIR/namedCredentials/SelfREST.namedCredential-meta.xml"
EC_FILE="$SOURCE_DIR/externalCredentials/SelfREST_Ext.externalCredential-meta.xml"

ORG_ALIAS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    --org | -o)
        shift
        [[ $# -gt 0 ]] || {
            echo "Error: Missing value for --org"
            exit 2
        }
        ORG_ALIAS="$1"
        ;;
    --help | -h)
        echo "Usage: ./e2e/create_named_credential.sh [--org <alias>]"
        exit 0
        ;;
    *)
        echo "Error: Unknown argument '$1'"
        echo "Usage: ./e2e/create_named_credential.sh [--org <alias>]"
        exit 2
        ;;
    esac
    shift
done

TARGET_ORG_ARGS=()
if [[ -n "$ORG_ALIAS" ]]; then
    TARGET_ORG_ARGS=(-o "$ORG_ALIAS")
fi

echo "Fetching connection info and API session token..."

# 1. Fetch Endpoint and AccessToken from org display
ORG_JSON=$(sf org display --json "${TARGET_ORG_ARGS[@]}")

if [[ $? -ne 0 ]]; then
    echo "Error: Could not fetch current org details. Ensure you are authenticated."
    exit 1
fi

ENDPOINT=$(echo "$ORG_JSON" | jq -r '.result.instanceUrl')
TOKEN=$(echo "$ORG_JSON" | jq -r '.result.accessToken')

if [[ -z "$ENDPOINT" || "$ENDPOINT" == "null" ]]; then
    echo "Error: Could not extract instanceUrl"
    exit 1
fi

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "Error: Could not extract accessToken."
    exit 1
fi

echo "Connection verified for: $ENDPOINT"
echo "Token length: ${#TOKEN} characters"

echo "Injecting values into placeholders..."

# 2. Create isolated backups
mkdir -p "$BACKUP_DIR"
cp "$NC_FILE" "$BACKUP_DIR/NC.bak"
cp "$EC_FILE" "$BACKUP_DIR/EC.bak"

# 3. SAFETY TRAP: Restore templates even if deployment fails
trap 'mv "$BACKUP_DIR/NC.bak" "$NC_FILE" 2>/dev/null || true; mv "$BACKUP_DIR/EC.bak" "$EC_FILE" 2>/dev/null || true; rm -rf "$BACKUP_DIR"; echo "Templates restored."' EXIT

# 4. Replace placeholders in the working files
sed "s|\${ENDPOINT}|$ENDPOINT|g" "$BACKUP_DIR/NC.bak" > "$NC_FILE"
sed "s|\${TOKEN}|$TOKEN|g" "$BACKUP_DIR/EC.bak" > "$EC_FILE"

echo "Deploying E2E Suite ($SOURCE_DIR)..."
sf project deploy start --source-dir "$SOURCE_DIR" --ignore-conflicts "${TARGET_ORG_ARGS[@]}"

echo "Assigning Permission Set..."
# We assign it to ourselves so we can access the credential
sf org assign permset --name "SelfREST_NC_Access" "${TARGET_ORG_ARGS[@]}" > /dev/null 2>&1 || true

echo "Done! E2E environment successfully configured and deployed."
