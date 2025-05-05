#!/usr/bin/env python3
import os
import sys
import subprocess
import csv
import glob

# File locations
locations = {
    "current": "/Users/melfranklin/Dontpullup/Dontpullup",
    "backup": "/Users/melfranklin/Dontpullup/Dontpullup.bak",
    "music": "/Users/melfranklin/Music/Dontpullup/Dontpullup",
    "merged": "/Users/melfranklin/DontpullupMerged",
    "recovered": "/Users/melfranklin/DontpullupFix"
}

# Load file list from CSV if available
def load_file_list():
    if os.path.exists("file_comparison_list.csv"):
        with open("file_comparison_list.csv", 'r') as csvfile:
            reader = csv.DictReader(csvfile)
            return list(reader)
    else:
        print("Generating file list...")
        subprocess.run(["python3", "compare_files.py"])
        return load_file_list()

# Compare files using selected tool
def compare_files(file_path, locations_to_compare, tool="vscode"):
    file_paths = []
    for loc in locations_to_compare:
        if loc in locations:
            full_path = os.path.join(locations[loc], file_path)
            if os.path.exists(full_path):
                file_paths.append(full_path)
    
    if len(file_paths) < 2:
        print(f"Not enough files to compare for {file_path}")
        return
    
    if tool == "vscode":
        # For VS Code, we can compare at most 2 files at once
        cmd = ["code", "--diff", file_paths[0], file_paths[1]]
    elif tool == "filemerge":
        # FileMerge can only compare 2 files
        cmd = ["opendiff", file_paths[0], file_paths[1]]
    elif tool == "terminal":
        # Terminal diff can only compare 2 files
        cmd = ["diff", "-u", file_paths[0], file_paths[1]]
    
    print(f"Comparing: {' and '.join(file_paths)}")
    subprocess.run(cmd)

# Interactive menu
def interactive_menu():
    file_list = load_file_list()
    
    while True:
        print("\n===== INTERACTIVE FILE COMPARISON AND MERGING =====")
        print("1. Show all files")
        print("2. Compare specific file")
        print("3. Bulk compare critical files")
        print("4. Copy a file from one location to another")
        print("5. Open a file in editor")
        print("6. Exit")
        
        choice = input("\nEnter your choice (1-6): ")
        
        if choice == "1":
            show_all_files(file_list)
        elif choice == "2":
            compare_specific_file(file_list)
        elif choice == "3":
            bulk_compare_critical_files()
        elif choice == "4":
            copy_file_between_locations()
        elif choice == "5":
            open_file_in_editor()
        elif choice == "6":
            print("Exiting...")
            break
        else:
            print("Invalid choice, please try again.")

# Show all files
def show_all_files(file_list):
    print("\nAll Swift files:")
    print("-" * 100)
    header = "| {:<2} | {:<40} |".format("#", "File Path")
    for location in locations.keys():
        header += " {:<8} |".format(location[:8])
    print(header)
    print("-" * 100)
    
    for i, row in enumerate(file_list):
        line = "| {:<2} | {:<40} |".format(i+1, row["file"][:40])
        for location in locations.keys():
            line += " {:<8} |".format(row[location])
        print(line)
    print("-" * 100)

# Compare specific file
def compare_specific_file(file_list):
    show_all_files(file_list)
    
    try:
        file_num = int(input("\nEnter file number to compare: ")) - 1
        if file_num < 0 or file_num >= len(file_list):
            print("Invalid file number")
            return
        
        file_path = file_list[file_num]["file"]
        print(f"\nSelected file: {file_path}")
        
        print("\nAvailable locations:")
        for i, (name, path) in enumerate(locations.items()):
            full_path = os.path.join(path, file_path)
            exists = "✓" if os.path.exists(full_path) else "✗"
            print(f"{i+1}. {name} ({exists})")
        
        loc_nums = input("\nEnter location numbers to compare (e.g., '1,3'): ")
        try:
            selected_locs = [list(locations.keys())[int(n.strip())-1] for n in loc_nums.split(",")]
            
            tools = {"1": "vscode", "2": "filemerge", "3": "terminal"}
            tool_choice = input("\nSelect comparison tool:\n1. VS Code\n2. FileMerge\n3. Terminal diff\nChoice: ")
            
            if tool_choice in tools:
                compare_files(file_path, selected_locs, tools[tool_choice])
            else:
                print("Invalid tool choice")
        except:
            print("Invalid location numbers")
    except:
        print("Invalid input")

# Critical files to check
critical_files = [
    "ViewModels/MapViewModel.swift",
    "ViewModels/AuthViewModel.swift", 
    "Views/MainTabView.swift",
    "Views/SplashScreen.swift",
    "App/dontpullupApp.swift",
    "Views/AuthView.swift",
    "Services/AuthState.swift"
]

# Bulk compare critical files
def bulk_compare_critical_files():
    print("\nCritical files to compare:")
    for i, file_path in enumerate(critical_files):
        print(f"{i+1}. {file_path}")
    
    try:
        file_num = int(input("\nEnter file number to compare (or 0 for all): "))
        if file_num < 0 or file_num > len(critical_files):
            print("Invalid file number")
            return
        
        tools = {"1": "vscode", "2": "filemerge", "3": "terminal"}
        tool_choice = input("\nSelect comparison tool:\n1. VS Code\n2. FileMerge\n3. Terminal diff\nChoice: ")
        
        if tool_choice not in tools:
            print("Invalid tool choice")
            return
        
        if file_num == 0:
            for file_path in critical_files:
                compare_files(file_path, ["current", "merged"], tools[tool_choice])
        else:
            file_path = critical_files[file_num-1]
            compare_files(file_path, ["current", "merged"], tools[tool_choice])
    except:
        print("Invalid input")

# Copy a file from one location to another
def copy_file_between_locations():
    file_list = load_file_list()
    show_all_files(file_list)
    
    try:
        file_num = int(input("\nEnter file number to copy: ")) - 1
        if file_num < 0 or file_num >= len(file_list):
            print("Invalid file number")
            return
        
        file_path = file_list[file_num]["file"]
        print(f"\nSelected file: {file_path}")
        
        print("\nSource locations:")
        for i, (name, path) in enumerate(locations.items()):
            full_path = os.path.join(path, file_path)
            exists = "✓" if os.path.exists(full_path) else "✗"
            print(f"{i+1}. {name} ({exists})")
        
        src_num = int(input("\nEnter source location number: ")) - 1
        if src_num < 0 or src_num >= len(locations):
            print("Invalid source location")
            return
        
        src_name = list(locations.keys())[src_num]
        src_path = os.path.join(locations[src_name], file_path)
        
        if not os.path.exists(src_path):
            print(f"File doesn't exist in {src_name}")
            return
        
        print("\nDestination locations:")
        for i, (name, path) in enumerate(locations.items()):
            if name != src_name:
                full_path = os.path.join(path, file_path)
                exists = "✓" if os.path.exists(full_path) else "✗"
                print(f"{i+1}. {name} ({exists})")
        
        dst_num = int(input("\nEnter destination location number: ")) - 1
        if dst_num < 0 or dst_num >= len(locations):
            print("Invalid destination location")
            return
        
        dst_name = list(locations.keys())[dst_num]
        dst_path = os.path.join(locations[dst_name], file_path)
        
        # Create directory if needed
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        
        # Copy file
        import shutil
        shutil.copy2(src_path, dst_path)
        print(f"Copied {file_path} from {src_name} to {dst_name}")
        
        # Refresh file list
        subprocess.run(["python3", "compare_files.py"])
    except Exception as e:
        print(f"Error: {e}")

# Open file in editor
def open_file_in_editor():
    file_list = load_file_list()
    show_all_files(file_list)
    
    try:
        file_num = int(input("\nEnter file number to open: ")) - 1
        if file_num < 0 or file_num >= len(file_list):
            print("Invalid file number")
            return
        
        file_path = file_list[file_num]["file"]
        print(f"\nSelected file: {file_path}")
        
        print("\nAvailable locations:")
        for i, (name, path) in enumerate(locations.items()):
            full_path = os.path.join(path, file_path)
            exists = "✓" if os.path.exists(full_path) else "✗"
            print(f"{i+1}. {name} ({exists})")
        
        loc_num = int(input("\nEnter location number to open: ")) - 1
        if loc_num < 0 or loc_num >= len(locations):
            print("Invalid location")
            return
        
        loc_name = list(locations.keys())[loc_num]
        full_path = os.path.join(locations[loc_name], file_path)
        
        if not os.path.exists(full_path):
            print(f"File doesn't exist in {loc_name}")
            return
        
        # Open in VS Code
        subprocess.run(["code", full_path])
    except:
        print("Invalid input")

if __name__ == "__main__":
    interactive_menu() 