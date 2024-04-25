#!/bin/bash

# A simple Bash script to list GCP firewall rules based on given target tags with complete details in JSON format

# Function to show usage and exit
usage() {
    echo "Usage: $0 --target-tags=tag1,tag2,tag3"
    exit 1
}

# Check if any arguments were passed
if [ $# -eq 0 ]; then
    usage
fi

# Parse arguments
for i in "$@"
do
case $i in
    --target-tags=*)
    TAGS="${i#*=}"
    shift # past argument=value
    ;;
    *)
    # unknown option
    usage
    ;;
esac
done

# Check if tags are provided
if [ -z "$TAGS" ]; then
    echo "Error: No tags provided."
    usage
fi

# Convert comma-separated list of tags to array
IFS=',' read -ra ADDR <<< "$TAGS"

# Iterate over each tag and list applicable firewall rules with complete details in JSON format
for tag in "${ADDR[@]}"; do
    echo "Listing firewall rules for tag: $tag"
    gcloud compute firewall-rules list --filter="targetTags=('${tag}')" --format=json
    echo "------------------------------------------------------"
done

