#!/bin/bash

# Deactivates all license fulfillment keys on a Linux Tableau Server.
#
# Usage:
#   sudo ./tableau-server-deactivate-all-licenses.bash         # prints what would happen, changes nothing
#   sudo ./tableau-server-deactivate-all-licenses.bash --yes   # deactivates all licenses
#
# Destructive: deactivated keys must be re-activated before the server can be licensed again.

load_environment_file() {
  local env_file=/etc/opt/tableau/tableau_server/environment.bash

  if [[ ! -f ${env_file} ]]; then
    echo "ERROR: environment file not found: ${env_file}" >&2
    return 1
  fi
  if ! source "${env_file}"; then
    echo "ERROR: failed to load environment file: ${env_file}" >&2
    return 1
  fi
  env_file_exists=1
}

deactivate_licenses() {
  local fulfillment_list
  local failed=0
  local id
  local licensing_url="https://licensing.tableau.com/flexnet/services/ActivationService?wsdl"
  local serveractutil_exe="/opt/tableau/tableau_server/packages/bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/serveractutil"

  if [[ ! -x "${serveractutil_exe}" ]]; then
    echo "ERROR: unable to find serveractutil at ${serveractutil_exe}" >&2
    return 1
  fi

  if ! fulfillment_list=$("${serveractutil_exe}" -view); then
    echo "ERROR: serveractutil -view failed" >&2
    return 1
  fi
  fulfillment_list=$(printf '%s\n' "${fulfillment_list}" | grep "Fulfillment ID" | cut -d " " -f 3)

  while IFS= read -r id; do
    [[ -z ${id} ]] && continue
    echo "===> Deactivating license fulfillment key: ${id}"
    if ! "${serveractutil_exe}" -return "${id}" -comm soap -reason 1 -commServer "${licensing_url}" < /dev/null; then
      echo "ERROR: failed to deactivate license fulfillment key: ${id}" >&2
      failed=1
    fi
  done <<< "${fulfillment_list}"

  return ${failed}
}

main() {
  if [[ "${1:-}" != "--yes" ]]; then
    echo "This script would deactivate ALL license fulfillment keys on this server"
    echo "by calling serveractutil -return for each 'Fulfillment ID' listed by serveractutil -view."
    echo "Nothing has been changed."
    echo "To proceed, re-run with --yes:  $0 --yes"
    exit 1
  fi

  if ! load_environment_file; then
    echo "ERROR: could not load the Tableau Server environment, aborting." >&2
    exit 1
  fi

  if ! deactivate_licenses; then
    echo "ERROR: license deactivation did not complete successfully." >&2
    exit 1
  fi

  echo "===> License deactivation complete."
}

main "$@"
