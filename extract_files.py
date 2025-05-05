import json
import os
import sys
import glob

# Define important files to recover
critical_files = [
    'AuthViewModel.swift',
    'SettingsView.swift',
    'ContentView.swift',
    'ProfileView.swift',
    'MapViewModel.swift',
    'SplashScreen.swift',
    'MainTabView.swift',
    'dontpullupApp.swift',
    'RootView.swift',
    'AuthView.swift',
    'AuthState.swift',
    'AuthenticationManager.swift',
    'UserAuthViewModel.swift',
    'FontManager.swift',
    'AppDelegate.swift',
    'SupportingViews.swift'
]

# Backup directories to search in order of recency
backup_dirs = [
    '/Users/melfranklin/.cache/github-copilot/project-context/Dontpullup.f91b05ba',
    '/Users/melfranklin/.cache/github-copilot/project-context/Dontpullup.99a82dc3',
    '/Users/melfranklin/.cache/github-copilot/project-context/Dontpullupgit.66c1d1fb'
]

# Output directory
output_base = '/Users/melfranklin/DontpullupFix'

# Ensure output directories exist
for subdir in ["App", "Authentication", "Models", "Services", "Utils", "ViewModels", "Views"]:
    os.makedirs(os.path.join(output_base, subdir), exist_ok=True)

def extract_swift_from_json(json_file_path):
    """Extract Swift code from a GitHub Copilot JSON backup file"""
    try:
        with open(json_file_path, 'r') as f:
            raw_data = f.read()
        
        # Parse JSON
        data = json.loads(raw_data)
        
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
                
                return swift_code
        
        # If we couldn't extract from document chunks, see if it's a simple string
        if isinstance(data, str):
            return data
            
        return None
    except Exception as e:
        print(f"Error extracting from {json_file_path}: {e}")
        return None

def find_latest_backup(filename):
    """Find the most recent backup of a given file"""
    for backup_dir in backup_dirs:
        # Search for any file matching the pattern {filename}.*.json
        pattern = os.path.join(backup_dir, f"{filename}.*json")
        matches = glob.glob(pattern)
        
        if matches:
            # Sort by modification time, newest first
            matches.sort(key=os.path.getmtime, reverse=True)
            return matches[0]
    
    return None

def get_output_path(filename):
    """Determine the output path based on the file name"""
    if any(x in filename for x in ["ViewModel", "Model"]):
        subdir = "ViewModels"
    elif "View" in filename or "Screen" in filename or "TabView" in filename:
        subdir = "Views"
    elif "App" in filename or "AppDelegate" in filename:
        subdir = "App"
    elif "Auth" in filename and not "View" in filename:
        subdir = "Authentication"
    elif "Manager" in filename or "Service" in filename or "State" in filename:
        subdir = "Services"
    else:
        subdir = "Utils"
    
    return os.path.join(output_base, subdir, filename)

# Process each critical file
for filename in critical_files:
    print(f"Looking for {filename}...")
    backup_file = find_latest_backup(filename)
    
    if backup_file:
        print(f"  Found backup: {backup_file}")
        swift_code = extract_swift_from_json(backup_file)
        
        if swift_code:
            output_path = get_output_path(filename)
            with open(output_path, 'w') as out:
                out.write(swift_code)
            print(f"  Successfully recovered {filename} to {output_path}")
        else:
            print(f"  Could not extract Swift code from {backup_file}")
    else:
        print(f"  No backup found for {filename}")

print("\nRecovery complete! Check the files in /Users/melfranklin/DontpullupFix") 