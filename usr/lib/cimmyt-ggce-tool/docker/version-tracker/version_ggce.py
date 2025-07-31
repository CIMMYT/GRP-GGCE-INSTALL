import requests
import re
import os
import json
from urllib.parse import quote_plus

# Regular expression to validate the tag format (vYYYY.M.m)
TAG_REGEX = re.compile(r"^v\d{4}\.\d+\.\d+$")


# Path for the output JSON file
OUTPUT_FILE = "data/version.json"


def version_sort_key(version_string):
    """Creates a tuple of integers for sorting versions like YYYY.M.m."""
    try:
        # The string is expected to be without a 'v' prefix
        parts = version_string.split(".")
        return tuple(map(int, parts))
    except (ValueError, AttributeError):
        return (0, 0, 0)


def fetch_tags_for_project(project_url):
    """Fetches tags for a specific GitLab project."""
    try:
        # Extract the domain and project path
        domain = project_url.split("/")[2]
        project_path = "/".join(project_url.split("/")[3:])
        # Encode the project path for the API URL
        encoded_project_path = quote_plus(project_path)

        api_url = (
            f"https://{domain}/api/v4/projects/{encoded_project_path}/repository/tags"
        )

        response = requests.get(api_url, timeout=10)
        response.raise_for_status()  # Raises an error if the request fails

        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error connecting to {project_url}: {e}")
        return []


def main():
    """
    Fetches tags from GitLab by reading project URLs from a JSON file,
    merges them with existing versions, sorts them, and writes the result back.
    """
    print("Starting tag review...")

    # 1. Read or initialize project data from version.json
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r") as f:
                data = json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error: Could not read or parse {OUTPUT_FILE}. Error: {e}")
            return
    else:
        print(
            f"Info: {OUTPUT_FILE} not found. Initializing with default configuration."
        )
        data = {
            "projects": [
                {
                    "name": "ui",
                    "url": "https://gitlab.croptrust.org/grin-global/grin-global-ui",
                    "versions": [],
                    "env": "GG_CE_UI_VERSION",
                },
                {
                    "name": "server",
                    "url": "https://gitlab.croptrust.org/grin-global/grin-global-server",
                    "versions": [],
                    "env": "GG_CE_API_VERSION",
                },
            ]
        }

    # 2. Iterate through each project, fetch and update tags
    for project in data.get("projects", []):
        project_name = project.get("name", "Unknown")
        project_url = project.get("url")

        if not project_url:
            print(f"Warning: Skipping project '{project_name}' due to missing URL.")
            continue

        print(f"Checking project: {project_name} ({project_url})")

        # Use a set for efficient addition and duplicate handling.
        # This also normalizes existing versions by removing any 'v' prefix.
        processed_versions = {v.lstrip("v") for v in project.get("versions", [])}

        fetched_tags = fetch_tags_for_project(project_url)

        for tag in fetched_tags:
            tag_name = tag.get("name")
            if tag_name and TAG_REGEX.match(tag_name):
                version_without_v = tag_name.lstrip("v")
                if version_without_v not in processed_versions:
                    print(f"  New valid tag found: {tag_name}. Adding as {version_without_v}...")
                    processed_versions.add(version_without_v)

        # Sort the combined list of versions (now without 'v') and update the project object
        project["versions"] = sorted(
            list(processed_versions), key=version_sort_key, reverse=True
        )

    # 3. Write the updated data back to the file
    try:
        # Ensure the data directory exists before writing
        os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
        with open(OUTPUT_FILE, "w") as f:
            json.dump(data, f, indent=4)
        print(f"Successfully updated {OUTPUT_FILE}")
    except IOError as e:
        print(f"Error writing to {OUTPUT_FILE}: {e}")

    print("Tag review completed.")


if __name__ == "__main__":
    main()
