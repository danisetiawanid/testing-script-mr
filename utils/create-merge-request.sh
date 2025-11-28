create_merge_request() {
  local project_id=$1
  local repo_name=$2
  local source_branch=$3
  local target_branch=$4
  local milestone=$5
  local milestone_id=$6
  local title=$7
  local assign_id=$8
  local reviewer_id=$9
  local labels=${10}
  local squash=${11}

  repo_upper=$(echo "$repo_name" | tr '[:lower:]' '[:upper:]')

  # Curl output: body in stdout, HTTP code on the last line
  response=$(curl -s -w "\n%{http_code}" --insecure --request POST \
    "$GITLAB_API_URL/projects/$project_id/merge_requests" \
    --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
        \"source_branch\": \"$source_branch\",
        \"target_branch\": \"$target_branch\",
        \"title\": \"[REVIEW][$milestone][FEATURE-MERGE][$repo_upper] $title\",
        \"labels\": \"$labels\",
        \"assignee_ids\": [$assign_id],
        \"reviewer_ids\": [$reviewer_id],
        \"milestone_id\": $milestone_id,
        \"remove_source_branch\": true,
        \"squash\": $squash
    }")

  # Separate the body and the HTTP code (take the last line as http_code)
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "201" ]]; then
      echo "Creating merge request in $repo_upper Success from $source_branch to $target_branch" >&2
      echo "$body" | jq -r ".web_url" >&2
  else
      echo "Gagal membuat merge request di $repo_upper (HTTP $http_code)" >&2
      echo "$body" | jq . >&2
  fi
}
