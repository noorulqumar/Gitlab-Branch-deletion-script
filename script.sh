#!/bin/bash
echo """

  ____    ____        __       _    _   _____   _   _   ______    _____                 _____   _        ______       __       _    _   _    _   _____
 |  _ \  |  _ \      /  \     |  \ | | / ____) | | | | |  ____)  / ____)               / ____) | |      |  ____)     /  \     |  \ | | | |  | | |  __ \ 
 | |_) | | |_) |    / /\ \    | | \| || |      | |_| | | |___   ( (___                | |      | |      | |___      / /\ \    | | \| | | |  | | | |__) |
 |  _ <  |  _ /    / /__\ \   | |\ | || |      |  _  | |  ___)   \ __ \               | |      | |      |  ___)    / /__\ \   | |\ | | | |  | | |  __ / 
 | |_) | | || \   / ______ \  | | \  || |____  | | | | | |____   ____) )              | |____  | |____  | |____   / ______ \  | | \  | | |__| | | |
 |____/  |_| \_\ /_/      \_\ |_|  \_| \_____) |_| |_| |______) (_____/                \_____) |______) |______) /_/      \_\ |_|  \_|  \____/  |_|

"""
echo "################### 🌟 START: Fetching Group and Project Information 🌟 ###################"

# Creat a GitLab Personal Access Token and use it here
GITLAB_TOKEN="glpat-Z_xxxxxxxxxxx"

# Type your GitLab API URL, if we are using self-hosted gitlab server type the link according.
GITLAB_API="https://gitlab.com/api/v4"

# Function to add color to text
color_text() {
  echo -e "\e[$1m$2\e[0m"
}

# Function to get group ID by name
get_group_id() {
  local group_name=$1
  curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/groups?search=$group_name" | jq -r --arg name "$group_name" '.[] | select(.name==$name) | .id'
}

# Function to get project ID by name within a group
get_project_id() {
  local group_id=$1
  local project_name=$2
  curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/groups/$group_id/projects?search=$project_name" | jq -r --arg name "$project_name" '.[] | select(.name==$name) | .id'
}


####
# Check if a file was passed as an argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <file_path>"
    exit 1
fi

# Assign the first argument to the file_path variable
file_path="$1"

# Check if the file exists
if [[ ! -f "$file_path" ]]; then
    echo "❌ File not found: $file_path"
    exit 1
fi

# Read the file line by line
while IFS= read -r line; do
    # Skip empty lines or lines starting with a comment #
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Process the line
    echo "Processing project: $line"
    # Add your logic here, e.g., clone repository, etc.

    # Count the number of "/" in the line
    slash_count=$(echo "$line" | awk -F"/" '{print NF-1}')

    # Display the line and the count of "/"
    echo "Line: $line"
    echo "Number of slashes: $slash_count"

    IFS="/" read -ra parts <<< "$line"

    # Based on the count of slashes, print the appropriate parts
    if [[ $slash_count -eq 1 ]]; then
        echo "One slash found: ${parts[0]}"
        echo "${parts[1]}"
    elif [[ $slash_count -eq 2 ]]; then
        echo "Two slashes found: ${parts[0]}/${parts[1]}/${parts[2]}"
    elif [[ $slash_count -eq 3 ]]; then
        echo "Three slashes found: ${parts[0]}/${parts[1]}/${parts[2]}/${parts[3]}"
    else
        echo "Line with $slash_count slashes: $line"
    fi

    
done < "$file_path"

####


# Get the group ID for "idgital"
group_id=$(get_group_id "idgital")

if [ -z "$group_id" ]; then
  echo "$(color_text 31 "❌ Group 'idgital' not found.")"
  exit 1
fi

# Get the project ID for "microservices-state-clone" within the "idgital" group
project_id=$(get_project_id "$group_id" "microservices-state-clone")

if [ -z "$project_id" ]; then
  echo "$(color_text 31 "❌ Project 'microservices-state-clone' not found in group 'idgital'.")"
  exit 1
fi

# Get the current date in seconds since epoch
current_date=$(date +%s)
# Define one year in seconds (approx. 365 days)
one_year_seconds=$((365 * 24 * 60 * 60))

# Function to fetch all branches considering pagination
get_all_branches() {
  local project_id=$1
  local page=1
  local per_page=100
  local branches=()
  
  while :; do
    response=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/repository/branches?page=$page&per_page=$per_page")
    page_branches=$(echo "$response" | jq -r '.[].name')
    if [ -z "$page_branches" ]; then
      break
    fi
    branches+=($page_branches)
    page=$((page + 1))
  done
  
  echo "${branches[@]}"
}

# Function to get the last commit date for a branch
get_last_commit_date() {
  local project_id=$1
  local branch=$2
  response=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/repository/commits?ref_name=$branch&per_page=1")
  last_commit_date=$(echo "$response" | jq -r '.[0].committed_date')
  
  echo "$last_commit_date"
}

# Function to delete a branch
delete_branch() {
  local project_id=$1
  local branch=$2
  # URL-encode the branch name
  encoded_branch=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$branch', safe=''))")
  
  # Perform the delete operation
  response=$(curl --silent --request DELETE --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/repository/branches/$encoded_branch")
  
  # Check if the response contains an error
  if echo "$response" | grep -q '"error"'; then
    echo "$(color_text 31 "❌ Failed to delete branch '$branch'. Response: $response")"
  else
    echo "$(color_text 32 "✅ Branch '$branch' has been deleted.")"
  fi
}

# Redirect output to backend.csv
output_file="backend.csv"
echo "Group,Project,Branch,Last Commit Date" > "$output_file"

# Get branches and check their last commit dates
echo "$(color_text 34 "🚀 Group: idgital")"
echo "$(color_text 36 "  📂 Project: microservices-state-clone")"

branches=$(get_all_branches "$project_id")
counter=0

for branch in $branches; do
  # Skip branches that start with "release-"
  if [[ $branch == release-* ]]; then
    continue
  fi
  
  last_commit_date=$(get_last_commit_date "$project_id" "$branch")
  last_commit_seconds=$(date --date="$last_commit_date" +%s)
  
  if (( (current_date - last_commit_seconds) > one_year_seconds )); then
    counter=$((counter + 1))
    echo "$(color_text 33 "$counter. 🗂️ Branch: $branch (Last commit: $last_commit_date)")"
    echo "idgital,microservices-state-clone,$branch,$last_commit_date" >> "$output_file"
    
    # Delete the branch
    delete_branch "$project_id" "$branch"
  fi
done

echo "$(color_text 32 "Total number of branches with commits older than 1 year: $counter")"
echo "Total number of branches with commits older than 1 year: $counter" >> "$output_file"
