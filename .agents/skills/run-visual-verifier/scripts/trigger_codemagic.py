#!/usr/bin/env python3
import os
import sys
import time
import requests
import argparse
from dotenv import load_dotenv

load_dotenv()

CODEMAGIC_API_TOKEN = os.environ.get("CODEMAGIC_API_TOKEN")
if not CODEMAGIC_API_TOKEN:
    print("Error: CODEMAGIC_API_TOKEN not found in environment or .env file.")
    sys.exit(1)

HEADERS = {
    "Content-Type": "application/json",
    "x-auth-token": CODEMAGIC_API_TOKEN,
}

def trigger_build(app_id, workflow_id, branch="main"):
    url = "https://api.codemagic.io/builds"
    payload = {
        "appId": app_id,
        "workflowId": workflow_id,
        "branch": branch
    }
    response = requests.post(url, json=payload, headers=HEADERS)
    response.raise_for_status()
    data = response.json()
    build_id = data.get("buildId")
    print(f"Build triggered successfully. Build ID: {build_id}")
    return build_id

def wait_for_build(build_id):
    url = f"https://api.codemagic.io/builds/{build_id}"
    print(f"Polling build status for {build_id}...")
    while True:
        response = requests.get(url, headers=HEADERS)
        response.raise_for_status()
        data = response.json()
        build = data.get("build", {})
        status = build.get("status")
        if status in ["finished", "canceled", "timeout", "failed"]:
            print(f"Build completed with status: {status}")
            return build
        time.sleep(15)

def download_artifact(build, output_dir):
    artifacts = build.get("artifacts", [])
    if not artifacts:
        print("No artifacts found for this build.")
        sys.exit(1)
    
    os.makedirs(output_dir, exist_ok=True)
    for artifact in artifacts:
        url = artifact.get("url")
        name = artifact.get("name")
        print(f"Downloading artifact {name} from {url}...")
        r = requests.get(url, headers=HEADERS, stream=True)
        r.raise_for_status()
        out_path = os.path.join(output_dir, name)
        with open(out_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"Artifact downloaded to {out_path}")
        return out_path # Return the first artifact
    return None

def main():
    parser = argparse.ArgumentParser(description="Trigger and wait for Codemagic build")
    parser.add_argument("--app-id", required=True, help="Codemagic App ID")
    parser.add_argument("--workflow-id", required=True, help="Codemagic Workflow ID")
    parser.add_argument("--branch", default="main", help="Git branch to build")
    parser.add_argument("--output-dir", default="./build_artifacts", help="Directory to save artifacts")
    
    args = parser.parse_args()
    
    build_id = trigger_build(args.app_id, args.workflow_id, args.branch)
    build_data = wait_for_build(build_id)
    if build_data.get("status") != "finished":
        print("Build did not finish successfully.")
        sys.exit(1)
        
    download_artifact(build_data, args.output_dir)

if __name__ == "__main__":
    main()
