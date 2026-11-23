#!/bin/bash

# Must be run as root
[ "${EUID}" -ne 0 ] && {
    echo "ERROR: This script must be run as root. Canceling." >&2
    exit 1
  }

# Loads the Tableau Server environment once. Tries the profile script first, then the fallback file.
load_environment_file() {
  local env_file

  for env_file in /etc/profile.d/tableau_server.sh /etc/opt/tableau/tableau_server/environment.bash; do
    if [[ -f "${env_file}" ]]; then
      if ! source "${env_file}"; then
        echo "ERROR: failed to load Tableau Server environment from ${env_file}" >&2
        return 1
      fi
      return 0
    fi
  done

  echo "ERROR: could not find a Tableau Server environment file (/etc/profile.d/tableau_server.sh or /etc/opt/tableau/tableau_server/environment.bash)" >&2
  return 1
}

if ! load_environment_file; then
  exit 1
fi

if [[ -z "${TABLEAU_SERVER_DATA_DIR}" ]]; then
  echo "ERROR: TABLEAU_SERVER_DATA_DIR is not set. Check the Tableau Server environment." >&2
  exit 1
fi

if [[ -z "${TABLEAU_SERVER_UNPRIVILEGED_USERNAME}" ]]; then
  echo "ERROR: TABLEAU_SERVER_UNPRIVILEGED_USERNAME is not set. Check the Tableau Server environment." >&2
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
done

if [[ ! -e "${script_dir}" ]]; then
  if ! mkdir "${script_dir}"; then
    echo "ERROR: could not create ${script_dir}" >&2
    exit 1
  fi
fi

for script_file in "${scripts[@]}"; do
  if ! cp "${tmp_dir}/${script_file}" "${script_dir}/"; then
    echo "ERROR: could not copy ${script_file} to ${script_dir}" >&2
    exit 1
  fi
  chmod +x "${script_dir}/${script_file}"
done

if ! chown -R "${TABLEAU_SERVER_UNPRIVILEGED_USERNAME}:${TABLEAU_SERVER_UNPRIVILEGED_USERNAME}" "${script_dir}"; then
  echo "ERROR: could not set ownership on ${script_dir}" >&2
  exit 1
fi

# Script is set up, now to schedule in crontab
echo 'Tableau Server housekeeping script is now installed. Please refer to the script documentation to schedule in crontab'
