#!/usr/bin/env python3
import os
import sys
import requests
import argparse
from dotenv import load_dotenv

load_dotenv()

APPETIZE_API_TOKEN = os.environ.get("APPETIZE_API_TOKEN")
if not APPETIZE_API_TOKEN:
    print("Error: APPETIZE_API_TOKEN not found in environment or .env file.")
    sys.exit(1)

def upload_app(file_path, platform):
    url = "https://APPETIZE_API_TOKEN@api.appetize.io/v1/apps"
    url = url.replace("APPETIZE_API_TOKEN", APPETIZE_API_TOKEN)
    
    print(f"Uploading {file_path} to Appetize.io...")
    with open(file_path, 'rb') as f:
        files = {'file': f}
        data = {'platform': platform}
        response = requests.post(url, files=files, data=data)
    
    response.raise_for_status()
    result = response.json()
    print("Upload successful!")
    print(f"App PublicKey: {result.get('publicKey')}")
    print(f"App URL: {result.get('appURL')}")
    return result

def main():
    parser = argparse.ArgumentParser(description="Upload artifact to Appetize.io")
    parser.add_argument("--file", required=True, help="Path to .app or .apk file")
    parser.add_argument("--platform", required=True, choices=["ios", "android"], help="Platform (ios or android)")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.file):
        print(f"Error: File {args.file} does not exist.")
        sys.exit(1)
        
    upload_app(args.file, args.platform)

if __name__ == "__main__":
    main()
