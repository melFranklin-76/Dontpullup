# Dontpullup Pin Management Implementation Summary

## Pin Reporting Flow (Long Press → Type → Video → Upload)

1. **Authentication**
   - Users MUST be signed in to drop pins
   - Each pin stores the creator's userId

2. **Pin Creation Flow**
   - Long press on map (within 200 feet of current location)
   - Simple incident type picker appears immediately
   - User selects incident type
   - Native iOS Photos app picker appears immediately
   - User selects video (3 min max)
   - Return to map with minimal upload progress indicator
   - Pin appears with incident emoji once upload completes

3. **Pin Filtering**
   - User taps cell phone emoji button to see only their pins
   - Toggle filters to see different incident types

4. **Pin Deletion**
   - User taps pencil icon to enter edit mode
   - User can tap their own pins to delete them
   - User taps pencil icon again to exit edit mode

## Key Code Requirements

```swift
// Authentication check before dropping pin
guard let currentUserId = Auth.auth().currentUser?.uid else {
    // Show error: "You need to sign in to drop pins"
    return
}

// Distance check (200 feet/61 meters)
let distance = userLocation.distance(from: pinLocation)
let withinRange = distance <= 200 * 0.3048

// Ownership check for deletion
func userCanEditPin(_ pin: Pin) -> Bool {
    guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
    return pin.userId == currentUserId
}
```

## Core Principles
- Minimalist, streamlined UI
- Immediate transitions between steps
- No custom camera interfaces
- No multi-step wizard or complex flows
- Real-time updates to all users
- Authorization checks for all operations
- Simple, non-blocking upload progress 