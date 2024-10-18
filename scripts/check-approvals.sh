#!/bin/bash
set -e

# GitHub API base URL
API_URL="https://api.github.com"

# Get the list of all team members
TEAM_MEMBERS=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "${API_URL}/orgs/${ORG_NAME}/teams/${TEAM_SLUG}/members" | jq -r '.[].login')

# Fetch pull request number and repository details from environment variables
PR_NUMBER=$(jq --raw-output .number < "$GITHUB_EVENT_PATH")
REPO_OWNER=$(jq --raw-output .repository.owner.login < "$GITHUB_EVENT_PATH")
REPO_NAME=$(jq --raw-output .repository.name < "$GITHUB_EVENT_PATH")

# Get the list of approvals for the pull request
APPROVALS=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "${API_URL}/repos/${REPO_OWNER}/${REPO_NAME}/pulls/${PR_NUMBER}/reviews" | \
  jq -r '.[] | select(.state == "APPROVED") | .user.login' | sort -u)

# Convert team members into a set
declare -A TEAM_SET
for member in $TEAM_MEMBERS; do
  TEAM_SET["$member"]=1
done

# Track missing approvals
missing_approvals=0

# Iterate over the list of approvals
for approval in $APPROVALS; do
  unset TEAM_SET["$approval"]
done

# If the set still has members, they haven't approved
for member in "${!TEAM_SET[@]}"; do
  echo "Missing approval from: $member"
  missing_approvals=$((missing_approvals + 1))
done

# Fail if not all team members approved
if [ $missing_approvals -ne 0 ]; then
  echo "All team members have NOT approved the pull request."
  exit 1
else
  echo "All team members have approved the pull request."
fi
