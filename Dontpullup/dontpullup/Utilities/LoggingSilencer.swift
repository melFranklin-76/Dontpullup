// Only include in Release builds to silence Print statements
#if !DEBUG
import Foundation

/// Overrides the global `print` function to no-op in Release to prevent verbose console output.
/// This is a lightweight compile-time replacement and has **zero** runtime cost.
@inline(__always)
public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    // No-op in production
}
#endif 