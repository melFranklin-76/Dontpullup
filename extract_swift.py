import os
import json
import sys

def extract_from_folder(src_folder, dst_folder):
    """Extract Swift code from GitHub Copilot JSON files and save as Swift files"""
    
    # Create destination folder if it doesn't exist
    os.makedirs(dst_folder, exist_ok=True)
    
    # Create necessary subdirectories
    for subdir in ["App", "Authentication", "Models", "Services", "Utils", "ViewModels", "Views"]:
        os.makedirs(os.path.join(dst_folder, subdir), exist_ok=True)
    
    # Get list of all JSON files in the source folder
    json_files = [f for f in os.listdir(src_folder) if f.endswith('.json')]
    
    print(f"Found {len(json_files)} JSON files in {src_folder}")
    
    for json_file in json_files:
        # Skip some JSON files that don't contain Swift code
        if "Contents.json" in json_file:
            continue
        
        file_path = os.path.join(src_folder, json_file)
        
        try:
            with open(file_path, 'r') as f:
                # GitHub Copilot JSON files may just contain the raw code as a string
                # Rather than parsing as JSON, try to read the raw contents first
                try:
                    raw_content = f.read().strip()
                    
                    # If it starts and ends with quotes, it might be a JSON string
                    if (raw_content.startswith('"') and raw_content.endswith('"')) or (raw_content.startswith("'") and raw_content.endswith("'")):
                        try:
                            # Try to parse as JSON
                            swift_code = json.loads(raw_content)
                        except:
                            # If not valid JSON, use the raw content
                            swift_code = raw_content
                    else:
                        # Try to parse as JSON object
                        try:
                            data = json.loads(raw_content)
                            if isinstance(data, dict) and "content" in data:
                                swift_code = data["content"]
                            else:
                                swift_code = raw_content
                        except:
                            swift_code = raw_content
                    
                    # Extract base filename
                    parts = json_file.split('.')
                    if len(parts) >= 3 and parts[-1] == 'json':
                        # Format is likely filename.hash.json
                        base_name = parts[0]
                    else:
                        base_name = os.path.splitext(json_file)[0]
                    
                    # Determine the full Swift filename
                    if base_name.endswith('.swift'):
                        swift_file = base_name
                    else:
                        swift_file = f"{base_name}.swift"
                    
                    # Determine the appropriate subdirectory
                    if "ViewModel" in swift_file:
                        subdir = "ViewModels"
                    elif "View" in swift_file or "TabView" in swift_file or "Screen" in swift_file:
                        subdir = "Views"
                    elif "App" in swift_file or "AppDelegate" in swift_file:
                        subdir = "App"
                    elif "Auth" in swift_file and not "View" in swift_file:
                        subdir = "Authentication"
                    elif "Type" in swift_file or "Model" in swift_file or "Pin" in swift_file:
                        subdir = "Models"
                    elif "Manager" in swift_file or "Service" in swift_file or "State" in swift_file:
                        subdir = "Services"
                    else:
                        subdir = "Utils"
                    
                    # Save the Swift code to a file
                    swift_path = os.path.join(dst_folder, subdir, os.path.basename(swift_file))
                    
                    with open(swift_path, 'w') as sf:
                        sf.write(swift_code)
                    
                    print(f"Extracted {swift_file} to {swift_path}")
                    
                except Exception as e:
                    print(f"Error processing content of {json_file}: {e}")
        except Exception as e:
            print(f"Error opening {json_file}: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python extract_swift.py <source_folder> <destination_folder>")
        sys.exit(1)
    
    src_folder = sys.argv[1]
    dst_folder = sys.argv[2]
    
    extract_from_folder(src_folder, dst_folder) 