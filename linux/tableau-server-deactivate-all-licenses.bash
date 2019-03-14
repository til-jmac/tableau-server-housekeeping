#!/bin/bash

# This script deactivates all licenses on a Linux Tableau Server

load_environment_file() {
  if [[ -f /etc/opt/tableau/tableau_server/environment.bash ]]; then
    source /etc/opt/tableau/tableau_server/environment.bash
    env_file_exists=1
  fi
}

deactivate_licenses() {
  local fulfillment_list
  local licensing_url="https://licensing.tableau.com/flexnet/services/ActivationService?wsdl"
  local serveractutil_exe=/opt/tableau/tableau_server/packages/bin.${TABLEAU_SERVER_DATA_DIR_VERSION}/serveractutil

  if [[ -x ${serveractutil_exe} ]]; then
    fulfillment_list=$(${serveractutil_exe} -view | grep "Fulfillment ID" | cut -d " " -f 3)
    for id in ${fulfillment_list}
    do
      echo "===> Deactivating license fulfillment key: ${id}"
      ${serveractutil_exe} -return "${id}" -comm soap -reason 1 -commServer "${licensing_url}"
    done
  else
    echo "===> Unable to find serveractutil, skipping license deactivation."
  fi
}