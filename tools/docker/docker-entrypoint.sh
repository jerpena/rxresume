#!/bin/sh
# vim:sw=4:ts=4:et

set -e

# shellcheck disable=SC2148
# EXPANDING VARIABLES FROM DOCKER SECRETS
# shellcheck disable=SC2223
: ${ENV_SECRETS_DIR:=/run/secrets}

env_secret_debug() {
  # shellcheck disable=SC2236
  if [ ! -z "$ENV_SECRETS_DEBUG" ]; then
    # shellcheck disable=SC2145
    echo -e "\033[1m$@\033[0m"
  fi
}

# usage: env_secret_expand VAR
#    ie: env_secret_expand 'XYZ_DB_PASSWORD'
# (will check for "$XYZ_DB_PASSWORD" variable value for a placeholder that defines the
#  name of the docker secret to use instead of the original value. For example:
# XYZ_DB_PASSWORD="DOCKER-SECRET->:my-db_secret"
env_secret_expand() {
  var="$1"
  # shellcheck disable=SC2086
  eval val=\$$var
  # shellcheck disable=SC2308
  if secret_name=$(expr match "$val" "DOCKER-SECRET->\([^}]\+\)$"); then
    secret="${ENV_SECRETS_DIR}/${secret_name}"
    env_secret_debug "Secret file for $var: $secret"
    if [ -f "$secret" ]; then
      val=$(cat "${secret}")
      export "$var"="$val"
      echo "$var"
      env_secret_debug "Expanded variable: $var=$val"
    else
      env_secret_debug "Secret file does not exist! $secret"
    fi
  fi
}

env_secrets_expand() {
  for env_var in $(printenv | cut -f1 -d"="); do
    # shellcheck disable=SC2086
    env_secret_expand $env_var
  done

  if [ ! -z "$ENV_SECRETS_DEBUG" ]; then
    echo -e "\n\033[1mExpanded environment variables\033[0m"
    printenv
  fi
}

env_secrets_expand

# shellcheck disable=SC2162
# shellcheck disable=SC2034
if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
  echo "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

  echo "$0: Looking for shell scripts in /docker-entrypoint.d/"
  find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
    case "$f" in
    *.sh)
      if [ -x "$f" ]; then
        echo "$0: Launching $f"
        "$f"
      else
        # warn on shell scripts without exec bit
        echo "$0: Ignoring $f, not executable"
      fi
      ;;
    *) echo "$0: Ignoring $f" ;;
    esac
  done

  echo "$0: Configuration complete; ready for start up"
else
  echo "$0: No files found in /docker-entrypoint.d/, skipping configuration"
fi

exec "$@"
