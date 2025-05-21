import Foundation
import SwiftUI

// This is a utility script to fix unreachable catch blocks in IncidentPickers.swift
// Run this script manually to fix the warnings

// Helper extension to make any function throwing-compatible
extension Result where Failure == Error {
    // Safely execute a potential throwing function
    static func execute(_ block: () throws -> Success) -> Result<Success, Failure> {
        do {
            return .success(try block())
        } catch {
            return .failure(error)
        }
    }
    
    // Safely execute a non-throwing function
    static func executeNonThrowing(_ block: () -> Success) -> Result<Success, Failure> {
        return .success(block())
    }
}

func fixUnreachableCatch() {
    // Get path to IncidentPickers.swift
    let currentDirectory = FileManager.default.currentDirectoryPath
    let filePath = "\(currentDirectory)/Dontpullup/Views/IncidentPickers.swift"
    
    do {
        // Read the file
        let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
        
        // Split into lines
        var lines = fileContents.components(separatedBy: .newlines)
        
        // Find unreachable catch blocks
        var i = 0
        var fixCount = 0
        while i < lines.count - 2 {
            // Look for patterns like:
            // do {
            //    code without try
            // } catch {
            //    ...
            // }
            
            if lines[i].trimmingCharacters(in: .whitespaces).contains("do {") {
                let doLine = i
                var tryFound = false
                var catchLine = -1
                
                // Look ahead for catch or try
                var j = i + 1
                while j < lines.count {
                    if lines[j].trimmingCharacters(in: .whitespaces).contains("catch") {
                        catchLine = j
                        break
                    }
                    if lines[j].contains("try") {
                        tryFound = true
                    }
                    j += 1
                }
                
                // If we found a catch but no try, this is unreachable
                if catchLine > 0 && !tryFound {
                    print("Found unreachable catch at line \(catchLine + 1)")
                    fixCount += 1
                    
                    // Remove the do line by commenting it out
                    lines[doLine] = "// FIXED: " + lines[doLine]
                    
                    // Remove the catch block by commenting it out
                    var k = catchLine
                    var braceCount = 1
                    while k < lines.count && braceCount > 0 {
                        if lines[k].contains("{") { braceCount += 1 }
                        if lines[k].contains("}") { braceCount -= 1 }
                        lines[k] = "// FIXED: " + lines[k]
                        k += 1
                    }
                }
            }
            i += 1
        }
        
        // Write the modified file back to disk
        try lines.joined(separator: "\n").write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
        
        print("Fixed \(fixCount) unreachable catch blocks in the file")
        print("Updated original file at: \(filePath)")
    } catch {
        print("Error: \(error)")
    }
}

// Wrapper function to call from the app
func runFixUnreachableCatch() {
    fixUnreachableCatch()
}

// NOTE: When using this file in an app project, don't call functions directly at the top level.
// Use the runFixUnreachableCatch() function from your app code instead.
// 
// If running as a standalone script with "swift FixUnreachableCatch.swift", uncomment:
// fixUnreachableCatch() 