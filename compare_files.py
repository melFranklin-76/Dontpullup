import os
import csv
import glob
import sys

# Locations to compare
locations = {
    "current": "/Users/melfranklin/Dontpullup/Dontpullup",
    "backup": "/Users/melfranklin/Dontpullup/Dontpullup.bak",
    "music": "/Users/melfranklin/Music/Dontpullup/Dontpullup",
    "merged": "/Users/melfranklin/DontpullupMerged",
    "recovered": "/Users/melfranklin/DontpullupFix"
}

# Output file
output_file = "file_comparison_list.csv"

def generate_comparison_list():
    # Set to track all unique files
    all_files = set()
    
    # Find all Swift files in all locations
    for location_name, location_path in locations.items():
        if os.path.exists(location_path):
            swift_files = glob.glob(os.path.join(location_path, "**", "*.swift"), recursive=True)
            for file_path in swift_files:
                # Get the file path relative to the location
                rel_path = os.path.relpath(file_path, location_path)
                all_files.add(rel_path)
    
    # Create a list of files with their existence in each location
    comparison_data = []
    for file_path in sorted(all_files):
        row = {"file": file_path}
        
        # Check if file exists in each location
        for location_name, location_path in locations.items():
            if os.path.exists(location_path):
                full_path = os.path.join(location_path, file_path)
                row[location_name] = "✓" if os.path.exists(full_path) else "✗"
            else:
                row[location_name] = "N/A"
                
        comparison_data.append(row)
    
    # Write to CSV
    with open(output_file, 'w', newline='') as csvfile:
        fieldnames = ["file"] + list(locations.keys())
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for row in comparison_data:
            writer.writerow(row)
    
    print(f"Comparison list generated: {output_file}")
    print(f"Found {len(comparison_data)} unique Swift files across all locations")
    
    # Print terminal-friendly table of the first 10 files
    print("\nSample of files to compare:")
    print("-" * 100)
    header = "| {:<40} |".format("File Path")
    for location in locations.keys():
        header += " {:<10} |".format(location)
    print(header)
    print("-" * 100)
    
    for row in comparison_data[:10]:
        line = "| {:<40} |".format(row["file"][:40])
        for location in locations.keys():
            line += " {:<10} |".format(row[location])
        print(line)
    
    if len(comparison_data) > 10:
        print("... and more files")
    print("-" * 100)

if __name__ == "__main__":
    generate_comparison_list()
    print("\nTo compare specific files, use a diff tool like:")
    print("  1. FileMerge (part of Xcode): opendiff file1 file2")
    print("  2. VS Code: code --diff file1 file2")
    print("  3. Terminal: diff -u file1 file2") 