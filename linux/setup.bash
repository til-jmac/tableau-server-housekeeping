#!/bin/bash

# Must be run as root
[ "${EUID}" -ne 0 ] && {
    echo "ERROR: This script must be run as root. Canceling." >&2
    exit 1
  }

# Loads the Tableau Server environment. Sources the profile script and the environment file when present.
load_environment_file() {
  local env_file
  local loaded=0

  for env_file in /etc/profile.d/tableau_server.sh /etc/opt/tableau/tableau_server/environment.bash; do
    if [[ -f "${env_file}" ]]; then
      if source "${env_file}"; then
        loaded=1
      else
        echo "WARNING: failed to load Tableau Server environment from ${env_file}" >&2
      fi
    fi
  done

  if [[ ${loaded} -eq 0 ]]; then
    echo "ERROR: could not load a Tableau Server environment file (/etc/profile.d/tableau_server.sh or /etc/opt/tableau/tableau_server/environment.bash)" >&2
    return 1
  fi
  return 0
}

if ! load_environment_file; then
  exit 1
fi

if [[ -z "${TABLEAU_SERVER_DATA_DIR}" ]]; then
  echo "ERROR: TABLEAU_SERVER_DATA_DIR is not set. Check the Tableau Server environment." >&2
  exit 1
fi

# Some more variables
base_url='https://raw.githubusercontent.com/til-jmac/tableau-server-housekeeping/master/linux'
scripts=(
  tableau-server-backup.bash
  tableau-server-log-archive.bash
  tableau-server-cleanup.bash
)

script_dir="${TABLEAU_SERVER_DATA_DIR}/scripts"

# Download into a fresh temporary directory so reruns never pick up stale files
tmp_dir=$(mktemp -d) || {
    echo "ERROR: could not create a temporary directory." >&2
    exit 1
  }
trap 'rm -rf "${tmp_dir}"' EXIT

# Setting up housekeeping scripts
for script_file in "${scripts[@]}"; do
  if ! wget -q -O "${tmp_dir}/${script_file}" "${base_url}/${script_file}"; then
    echo "ERROR: failed to download ${base_url}/${script_file}" >&2
    exit 1
  fi
  if [[ ! -s "${tmp_dir}/${script_file}" ]] || [[ "$(head -n 1 "${tmp_dir}/${script_file}")" != '#!'* ]]; then
    echo "ERROR: ${script_file} is empty or does not start with #!, not installing." >&2
    exit 1
  fi
done

# The scripts run as root or a tsm administrator from cron, so they and their directory must be root-owned
if [[ -L "${script_dir}" ]]; then
  echo "ERROR: ${script_dir} is a symlink, refusing to install into it." >&2
  exit 1
fi

if ! install -d -o root -g root -m 0755 "${script_dir}"; then
  echo "ERROR: could not create ${script_dir}" >&2
  exit 1
fi

for script_file in "${scripts[@]}"; do
  if ! install -o root -g root -m 0755 "${tmp_dir}/${script_file}" "${script_dir}/${script_file}"; then
    echo "ERROR: could not install ${script_file} to ${script_dir}" >&2
    exit 1
  fi
done

# Settings live in an optional file that setup never touches
settings_file=/etc/tableau-server-housekeeping.conf
if [[ -f "${settings_file}" ]]; then
  echo "Settings file: ${settings_file}"
else
  echo "Settings go in ${settings_file} (not found, script defaults are in use)"
fi

# Script is set up, now to schedule in crontab
echo 'Tableau Server housekeeping script is now installed. Please refer to the script documentation to schedule in crontab'
