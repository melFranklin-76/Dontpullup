import json
import sys
import os

# Specify the backup file
backup_file = '/Users/melfranklin/.cache/github-copilot/project-context/Dontpullupgit.66c1d1fb/SplashScreen.swift.2ae67d4e.json'
output_dir = '/Users/melfranklin/DontpullupFix/Views'
output_file = os.path.join(output_dir, 'SplashScreen.swift')

# Ensure output directory exists
os.makedirs(output_dir, exist_ok=True)

try:
    # Open and read the JSON backup file
    with open(backup_file, 'r') as f:
        raw_data = f.read()
    
    print(f"Raw data type: {type(raw_data).__name__}")
    print(f"Raw data length: {len(raw_data)}")
    print(f"Raw data starts with: {raw_data[:100]}...")
    
    # Parse JSON
    try:
        data = json.loads(raw_data)
        print(f"Parsed data type: {type(data).__name__}")
        
        # Extract Swift code from document chunks
        swift_code = ""
        if isinstance(data, dict) and "documentChunks" in data:
            chunks = data["documentChunks"]
            if isinstance(chunks, list):
                # Sort chunks by their range.start value if available
                try:
                    chunks = sorted(chunks, key=lambda x: x.get("range", {}).get("start", 0))
                except:
                    # If sorting fails, just use them in the order they appear
                    pass
                
                # Extract the code from each chunk
                for chunk in chunks:
                    if "chunk" in chunk:
                        swift_code += chunk["chunk"]
        else:
            swift_code = str(data)
        
        # Write the extracted content to the output file
        with open(output_file, 'w') as out:
            out.write(swift_code)
        print(f"Successfully extracted SplashScreen.swift to {output_file}")
        
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        # Try to extract code directly from the raw file if JSON parsing fails
        if raw_data.startswith('"') and raw_data.endswith('"'):
            # It's likely a JSON-encoded string, try to decode it
            try:
                code = json.loads(raw_data)
                with open(output_file, 'w') as out:
                    out.write(code)
                print(f"Successfully extracted SplashScreen.swift (from string) to {output_file}")
            except Exception as e2:
                print(f"Failed to extract from JSON string: {e2}")
        else:
            print("Raw data doesn't appear to be a valid JSON format")
            # Just write the raw data as a fallback
            with open(output_file, 'w') as out:
                out.write(raw_data)
            print(f"Wrote raw data to {output_file}")
            
except Exception as e:
    print(f"Error: {e}") 