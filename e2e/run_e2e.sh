#!/bin/bash

# run_e2e.sh
# Package-aware E2E setup + execution.
#
# Usage:
#   bash e2e/run_e2e.sh
#   bash e2e/run_e2e.sh --packages apex-query,apex-sql-query
#   bash e2e/run_e2e.sh --packages apex-cdp-query --org TestOrg
#
# Supported package names:
#   - apex-query
#   - apex-sql-query
#   - apex-cdp-query
#
# Package to suite mapping:
#   apex-query      -> soql + soql-external
#   apex-sql-query  -> sql
#   apex-cdp-query  -> cdp

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    cat <<'EOF'
Usage: bash e2e/run_e2e.sh [--packages <csv>] [--org <alias>]

Options:
  --packages   Comma-separated package names. Default: apex-query,apex-sql-query
  --org        Target org alias (optional)
  -h, --help   Show help
EOF
}

PACKAGES_CSV="apex-query,apex-sql-query"
ORG_ALIAS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --packages)
        shift
        [[ $# -gt 0 ]] || {
            echo -e "${RED}Missing value for --packages${NC}"
            exit 2
        }
        PACKAGES_CSV="$1"
        ;;
    --org | -o)
        shift
        [[ $# -gt 0 ]] || {
            echo -e "${RED}Missing value for --org${NC}"
            exit 2
        }
        ORG_ALIAS="$1"
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    *)
        echo -e "${RED}Unknown argument: $1${NC}"
        usage
        exit 2
        ;;
    esac
    shift
done

target_org_args=()
if [[ -n "$ORG_ALIAS" ]]; then
    target_org_args=(-o "$ORG_ALIAS")
fi

declare -A selected=()
while IFS= read -r raw; do
    pkg="$(echo "$raw" | xargs)"
    [[ -z "$pkg" ]] && continue
    case "$pkg" in
    apex-query | apex-sql-query | apex-cdp-query)
        selected["$pkg"]=1
        ;;
    *)
        echo -e "${RED}Unsupported package: ${pkg}${NC}"
        echo -e "Supported values: apex-query, apex-sql-query, apex-cdp-query"
        exit 2
        ;;
    esac
done < <(echo "$PACKAGES_CSV" | tr ', ' '\n')

if [[ ${#selected[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No packages selected. Nothing to do.${NC}"
    exit 0
fi

has_apex_query=0
has_apex_sql=0
run_soql=0
run_soql_external=0
run_sql=0
run_cdp=0
needs_data_seed=0

if [[ -n "${selected[apex-query]:-}" ]]; then
    has_apex_query=1
    run_soql=1
    run_soql_external=1
    needs_data_seed=1
fi
if [[ -n "${selected[apex-sql-query]:-}" ]]; then
    # SQL package depends on core query package in deployment/runtime
    has_apex_query=1
    has_apex_sql=1
    run_sql=1
fi
if [[ -n "${selected[apex-cdp-query]:-}" ]]; then
    # DataCloud org is treated as preconfigured; run tests only
    run_cdp=1
fi

echo -e "${BLUE}=== Starting E2E Setup ===${NC}"
echo -e "Packages: ${PACKAGES_CSV}"
if [[ -n "$ORG_ALIAS" ]]; then
    echo -e "Target org: ${ORG_ALIAS}"
fi

# 1) Deploy required source + e2e metadata
deploy_args=()
if [[ $has_apex_query -eq 1 ]]; then
    deploy_args+=(-d sfdx-source/apex-query)
fi
if [[ $has_apex_sql -eq 1 ]]; then
    deploy_args+=(-d sfdx-source/apex-sql-query)
fi
if [[ $run_soql -eq 1 ]]; then
    deploy_args+=(-d e2e/main/soql)
fi
if [[ $run_sql -eq 1 ]]; then
    deploy_args+=(-d e2e/main/sql)
fi

if [[ ${#deploy_args[@]} -gt 0 ]]; then
    echo -e "${BLUE}[1/5] Deploying required metadata...${NC}"
    sf project deploy start "${target_org_args[@]}" "${deploy_args[@]}" --wait 20
    echo -e "${GREEN}Metadata deployed successfully.${NC}"
else
    echo -e "${YELLOW}[1/5] No metadata deployment required for selected packages.${NC}"
fi

# 2) Configure Self REST named credential only when soql-external is needed
if [[ $run_soql_external -eq 1 ]]; then
    echo -e "${BLUE}[2/5] Configuring SelfREST named credential...${NC}"
    if [[ -n "$ORG_ALIAS" ]]; then
        bash e2e/create_named_credential.sh --org "$ORG_ALIAS"
    else
        bash e2e/create_named_credential.sh
    fi
else
    echo -e "${YELLOW}[2/5] No named credential setup required for selected packages.${NC}"
fi

# 3) Assign needed permission sets
if [[ $run_soql -eq 1 ]]; then
    echo -e "${BLUE}[3/5] Assigning permission sets...${NC}"
    sf org assign permset --name E2E_Permissions "${target_org_args[@]}" || echo "Could not assign E2E_Permissions; continuing."
    echo -e "${GREEN}Permission set assignment completed.${NC}"
else
    echo -e "${YELLOW}[3/5] No permission set assignment required for selected packages.${NC}"
fi

# 4) Seed SOQL data only when needed
if [[ $needs_data_seed -eq 1 ]]; then
    echo -e "${BLUE}[4/5] Cleaning and importing SOQL E2E data...${NC}"
    sf apex run -f e2e/cleanup_data.apex "${target_org_args[@]}"

    DATA_DIR="e2e/data"
    import_data() {
        local sobject=$1
        local file=$2
        local extid=$3

        echo -e "Importing ${sobject}..."
        if [[ -z "$extid" ]]; then
            sf data import bulk -s "$sobject" -f "$DATA_DIR/$file" --wait 20 "${target_org_args[@]}"
        else
            sf data upsert bulk -s "$sobject" -f "$DATA_DIR/$file" -i "$extid" --wait 30 "${target_org_args[@]}"
        fi
    }

    import_data "CurrencyType" "CurrencyType.csv" ""
    import_data "Account" "Account.csv" "ExternalId__c"
    import_data "Contact" "Contact.csv" "ExternalId__c"
    import_data "Case" "Case.csv" "ExternalId__c"
    import_data "Task" "Task.csv" "ExternalId__c"
    import_data "FeedItem" "FeedItem.csv" ""
    echo -e "${GREEN}SOQL data import completed.${NC}"
else
    echo -e "${YELLOW}[4/5] No data seed required for selected packages.${NC}"
fi

echo -e "${GREEN}=== E2E Setup Finished ===${NC}"

# 5) Run selected suites
echo -e "${BLUE}[5/5] Running selected E2E suites...${NC}"
overall_failed=0
run_suite_script() {
    local script="$1"
    if [[ -n "$ORG_ALIAS" ]]; then
        bash "$script" "$ORG_ALIAS" || overall_failed=1
    else
        bash "$script" || overall_failed=1
    fi
}

if [[ $run_soql -eq 1 ]]; then
    run_suite_script "e2e/run_soql_tests.sh"
fi
if [[ $run_soql_external -eq 1 ]]; then
    run_suite_script "e2e/run_soql_external_tests.sh"
fi
if [[ $run_sql -eq 1 ]]; then
    run_suite_script "e2e/run_sql_tests.sh"
fi
if [[ $run_cdp -eq 1 ]]; then
    run_suite_script "e2e/run_cdp_tests.sh"
fi

exit $overall_failed
