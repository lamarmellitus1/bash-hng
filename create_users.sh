#!/bin/bash

# Check if the script is run with a file argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 user_list.txt"  # create a user file here, that the script can read it.
    exit 1
fi

# Input file containing usernames and groups
input_file="$1"

# Log file
log_file="/var/log/user_management.log"
# Password file
password_file="/var/secure/user_passwords.csv"

# Create log and password files
touch "$log_file"
touch "$password_file"

# Ensure secure password file permissions
chmod 600 "$password_file"

# Function to generate random password
generate_password() {
    tr -dc 'A-Za-z0-9@#$%&*' < /dev/urandom | head -c 12
}

# Read the input file line by line
while IFS=';' read -r username groups; do
    # Remove leading/trailing whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    if [ -z "$username" ]; then
        echo "Skipped empty username." >> "$log_file"
        continue
    fi

    # Create user and personal group if they don't exist
    if id "$username" &>/dev/null; then
        echo "User $username already exists." >> "$log_file"
    else
        useradd -m "$username"
        echo "User $username created." >> "$log_file"
    fi

    if getent group "$username" &>/dev/null; then
        echo "Group $username already exists." >> "$log_file"
    else
        groupadd "$username"
        echo "Group $username created." >> "$log_file"
    fi

    usermod -g "$username" "$username"

    # Set up home directory permissions
    chown "$username":"$username" "/home/$username"
    chmod 700 "/home/$username"

    # Add user to additional groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs) # Remove whitespace
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
            echo "Group $group created." >> "$log_file"
        fi
        usermod -aG "$group" "$username"
        echo "User $username added to group $group." >> "$log_file"
    done

    # Generate and set password
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username,$password" >> "$password_file"
    echo "Password for user $username set." >> "$log_file"

done < "$input_file"

echo "User creation process completed." >> "$log_file"
