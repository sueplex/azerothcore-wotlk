#!/usr/bin/env bash
set -euo pipefail

#!/bin/sh

# Loop through all environment variables
for var in $(env | grep '_SECRET_FILE=' | sed 's/=.*//'); do
    # Read the file path from the environment variable
    file_path=$(printenv $var)

    # Check if the file exists
    if [ -f "$file_path" ]; then
        # Read the content of the file
        file_content=$(cat "$file_path")

        # Create a new environment variable name by removing the '_FILE' suffix
        new_var=$(echo $var | sed 's/_SECRET_FILE$//')

        # Export the new environment variable with the content of the file
        export $new_var="$file_content"
    else
        echo "File $file_path does not exist."
    fi
done

CONF_DIR="${CONF_DIR:-/azerothcore/env/dist/etc}"
LOGS_DIR="${LOGS_DIR:-/azerothcore/env/dist/logs}"

if ! touch "$CONF_DIR/.write-test" || ! touch "$LOGS_DIR/.write-test"; then
    cat <<EOF
===== WARNING =====
The current user doesn't have write permissions for
the configuration dir ($CONF_DIR) or logs dir ($LOGS_DIR).
It's likely that services will fail due to this.

This is usually caused by cloning the repository as root,
so the files are owned by root (uid 0).

To resolve this, you can set the ownership of the
configuration directory with the command on the host machine.
Note that if the files are owned as root, the ownership must
be changed as root (hence sudo).

$ sudo chown -R $(id -u):$(id -g) /path/to$CONF_DIR /path/to$LOGS_DIR

Alternatively, you can set the DOCKER_USER environment
variable (on the host machine) to "root", though this
isn't recommended.

$ DOCKER_USER=root docker-compose up -d
====================
EOF
fi

[[ -f "$CONF_DIR/.write-test" ]] && rm -f "$CONF_DIR/.write-test"
[[ -f "$LOGS_DIR/.write-test" ]] && rm -f "$LOGS_DIR/.write-test"

# Copy all default config files to env/dist/etc if they don't already exist
# -r == recursive
# -n == no clobber (don't overwrite)
# -v == be verbose
cp -rnv /azerothcore/env/ref/etc/* "$CONF_DIR"

CONF="$CONF_DIR/$ACORE_COMPONENT.conf"
CONF_DIST="$CONF_DIR/$ACORE_COMPONENT.conf.dist"

# Copy the "dist" file to the "conf" if the conf doesn't already exist
if [[ -f "$CONF_DIST" ]]; then
    cp -vn "$CONF_DIST" "$CONF"
else
    touch "$CONF"
fi

echo "Starting $ACORE_COMPONENT..."

binpath=$(echo $@ | awk '{print $NF}')
binname=$(basename $binpath)
pidfile="./env/dist/etc/$binname.pid"
touch $pidfile
printf "$$" > "$pidfile"

if [[ "$binname" == "worldserver" ]]; then
    pause=1
    trap 'pause=0 && rm $pidfile' SIGHUP
    while (( pause )); do sleep 2; done
fi

echo "Starting $ACORE_COMPONENT..."
exec "$@"

