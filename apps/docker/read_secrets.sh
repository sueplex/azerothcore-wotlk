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

exec /usr/local/bin/docker-entrypoint.sh $@
