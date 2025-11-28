import json
import sys

def sort_and_filter(json_str):
    # Load JSON data
    data = json.loads(json_str)

    # Sort by merged_at key (descending)
    sorted_data = sorted(
        data,
        key=lambda x: x.get('merged_at', ''),
        reverse=True
    )

    # Filter unique project_id
    seen_projects = set()
    filtered_data = []
    for item in sorted_data:
        project_id = item.get('project_id')
        if project_id not in seen_projects:
            seen_projects.add(project_id)
            filtered_data.append(item)

    return filtered_data

if __name__ == "__main__":
    # Make sure there is an input argument 
    if len(sys.argv) < 2:
        sys.exit(1)

    json_str = sys.argv[1]

    # Run function sort and filter
    filtered_json = sort_and_filter(json_str)

    # Print all unique merge request based on project_id.
    for item in filtered_json:
        print(f"{item.get('project_id', '')}")
