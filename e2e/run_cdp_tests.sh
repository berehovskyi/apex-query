#!/bin/bash
# Prerequisites:
# - Ingestion objects account/contact/case_record are loaded.
# - Data Streams map them to ssot__Account__dlm, ssot__Individual__dlm, ssot__Case__dlm.
# - Mapping jobs finished successfully in Data Cloud.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/run_tests.sh" cdp "$@"
