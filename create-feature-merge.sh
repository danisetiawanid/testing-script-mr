# Retrieve a stored variable.

read -rsp "Enter your shell password: " shell_password
echo ""

source "utils/retrieve-creds.sh" "$shell_password"
source "utils/create-merge-request.sh"

## The value of the Android Group ID
GROUP_ID="299"
## The value of Lead Reviewer ID
REVIEWER_ID="74"

## Save value for source branch
read -p "Source branch :" source_branch

## Save value for target branch
read -p "Target branch : " target_branch

## Save value for title
read -p "Create title : " title

## Save value for milestone
read -p "Milestone(e.g = R4.1): " milestone

## Add label hold when merge request not ready
read -p "Add Hold label?(y/n): " is_hold_label

## Change reviewer for default is lead (please input user id)
read -p "Change reviewer?*default is Lead*(y/n): " is_reviewer

## Use user id to input reviewer id
if [[ "$is_reviewer" == "y" ]]; then
    read -p "Input reviewer id(e.g = 77): " reviewer_id
    reviewer_id_value="$reviewer_id"
else
    reviewer_id_value="$REVIEWER_ID"
fi

## Checking is_squash is value y or others
read -p "Squash Commit?(y/n): " is_squash

## Save value when merge request is squash commit
if [[ "$is_squash" == "y" ]]; then
    squash=true
else
    squash=false
fi

## Save value when merge request is not ready and add label hold
if [[ "$is_hold_label" == "y" ]]; then
    labels="Feature:Merge, Hold"
else
    labels="Feature:Merge"
fi

## change directory to the previous directory
cd ..

echo ""
echo "-------------------------------------------------------------------------------------------------------------"
echo "                                Start create merge request 'FEATURE-MERGE'                                              "
echo "-------------------------------------------------------------------------------------------------------------"

## Get all merge request in source branch
get_target_mr() {
    local source_branch=$1
    local page=1

    ## Get data per page is 50 data
    local per_page=50
    local all_data="[]"

    while :; do
        ## The merge request URL that has been merged based on the source branch
        merged_url="$GITLAB_API_URL/groups/$GROUP_ID/merge_requests?state=merged&target_branch=$source_branch&per_page=$per_page&page=$page" >&2

        ## Get response body
        body=$(curl -s --insecure --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" "$merged_url")

        ## If body is empty → done
        if [[ -z "$body" ]]; then
            echo "Warning: Response is empty for this page=$page" >&2
            break
        fi

        ## Clear char control U+0000–U+001F using python to avoid "jq" parse errors
        clean_body=$(python3 - <<'PY' <<<"$body"
import re, sys
data = sys.stdin.read()
print(re.sub(r"[\x00-\x1f]", "", data))
PY
        )

        ## Check valid JSON
        if ! echo "$clean_body" | jq empty 2>/dev/null; then
            echo "Warning: Response not have valid JSON page=$page" >&2
            break
        fi

        ## Ensure the JSON type is an array
        response_type=$(echo "$clean_body" | jq -r 'type')
        if [[ "$response_type" != "array" ]]; then
            echo "Warning: Response is not array for this page=$page (type=$response_type)" >&2
            echo "Body: $clean_body" >&2
            break
        fi

        ## If array is empty -> done
        if [[ "$clean_body" == "[]" ]]; then
            break
        fi

        ## Merge data to all_data
        all_data=$(echo "$all_data" "$clean_body" | jq -s 'add')

        ## Page increment
        ((page++))
    done

    echo "Preparing....." >&2

    ## Only JSON as the stdout output
    echo "$all_data"
}

## Get milestone id from milestone name
get_milestone_id() {
    local milestone=$1

    MILESTONE_ID=$(curl -s --insecure --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" "$GITLAB_API_URL/groups/$GROUP_ID/milestones?search=$milestone" | jq '.[0].id')

    echo $MILESTONE_ID
}

## Get project name from project_id
get_project_name() {
    local project_id=$1

    repo_name=$(curl -s --insecure --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" "$GITLAB_API_URL/projects/$project_id" | jq -r ".name")

    echo $repo_name
}

## Get user id
get_user_id() {
    local username=$1

    USER_ID=$(curl -s --insecure --header "PRIVATE-TOKEN: $GITLAB_ACCESS_TOKEN" "$GITLAB_API_URL/user" | jq '.id')

    echo $USER_ID
}

main() {
    mr_data=$(get_target_mr "$source_branch")

    cd shell

    ## filter by project id using phyton script
    project_ids=($(python3 "utils/filter_by_project_id.py" "$mr_data"))
    
    assign_id=$(get_user_id $USERNAME)
    milestone_id=$(get_milestone_id $milestone)

    ## Loop for get all project name based on project ids
    repos_name=()
    for id in "${project_ids[@]}"; do
        name=$(get_project_name "$id")
        repos_name+=("$name")
    done

    ## Loop for create merge request in specific repository based on project ids
    for i in "${!project_ids[@]}"; do
        project_id="${project_ids[$i]}"
        repo_name="${repos_name[$i]}"

        create_merge_request "$project_id" "$repo_name" "$source_branch" "$target_branch" \
            "$milestone" "$milestone_id" "$title" "$assign_id" "$reviewer_id_value" "$labels" "$squash"
    done

}

export -f create_merge_request
export -f get_user_id
export -f get_project_name
export -f get_project_name
export -f get_milestone_id
export GITLAB_ACCESS_TOKEN GITLAB_API_URL

main