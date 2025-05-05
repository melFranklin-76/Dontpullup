import os
import glob
import shutil
import time

# Source paths
music_dir = "/Users/melfranklin/Music/Dontpullup/Dontpullup"
recovery_dir = "/Users/melfranklin/Dontpullup/Dontpullup"

# Destination path
merged_dir = "/Users/melfranklin/DontpullupMerged"

# Ensure destination directories exist
for subdir in ["App", "Authentication", "Models", "Resources", "Services", "Utils", "ViewModels", "Views"]:
    os.makedirs(os.path.join(merged_dir, subdir), exist_ok=True)

# Create subdirectories that might be nested in App
os.makedirs(os.path.join(merged_dir, "App", "Utilities"), exist_ok=True)

def merge_files():
    # Track what we've processed
    processed_files = set()
    
    # Find all Swift files in both directories
    music_files = glob.glob(os.path.join(music_dir, "**", "*.swift"), recursive=True)
    recovery_files = glob.glob(os.path.join(recovery_dir, "**", "*.swift"), recursive=True)
    
    print(f"Found {len(music_files)} Swift files in Music directory")
    print(f"Found {len(recovery_files)} Swift files in Recovery directory")
    
    # Process music files first
    for src_path in music_files:
        # Determine the relative path within music_dir
        rel_path = os.path.relpath(src_path, music_dir)
        
        # Construct destination path
        dst_path = os.path.join(merged_dir, rel_path)
        
        # Create parent directory if needed
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        
        # Copy the file
        shutil.copy2(src_path, dst_path)
        print(f"Copied: {rel_path} (from Music)")
        
        # Mark as processed
        processed_files.add(rel_path)
    
    # Now process recovery files, only copying if newer or doesn't exist yet
    for src_path in recovery_files:
        # Determine the relative path within recovery_dir
        rel_path = os.path.relpath(src_path, recovery_dir)
        
        # Construct destination path
        dst_path = os.path.join(merged_dir, rel_path)
        
        # Check if this file has been processed already
        if rel_path in processed_files:
            # Compare modification times to see which is newer
            music_mtime = os.path.getmtime(os.path.join(merged_dir, rel_path))
            recovery_mtime = os.path.getmtime(src_path)
            
            if recovery_mtime > music_mtime:
                # If recovery file is newer, overwrite
                shutil.copy2(src_path, dst_path)
                print(f"Updated: {rel_path} (from Recovery - newer)")
            else:
                print(f"Kept: {rel_path} (from Music - newer)")
        else:
            # If not processed yet, create parent directory if needed
            os.makedirs(os.path.dirname(dst_path), exist_ok=True)
            
            # Copy the file
            shutil.copy2(src_path, dst_path)
            print(f"Added: {rel_path} (from Recovery)")
            
            # Mark as processed
            processed_files.add(rel_path)
    
    print(f"\nMerge complete! {len(processed_files)} total Swift files merged to {merged_dir}")

if __name__ == "__main__":
    merge_files() 