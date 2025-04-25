// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DontPullUp",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "10.29.0"))
    ],
    targets: [
        .target(
            name: "DontPullUp",
            dependencies: [
                .product(name: "FirebaseAuth", package: "Firebase"),
                .product(name: "FirebaseFirestore", package: "Firebase"),
                .product(name: "FirebaseDatabase", package: "Firebase"),
                .product(name: "FirebaseAnalytics", package: "Firebase"),
                .product(name: "FirebaseStorage", package: "Firebase")
            ],
            path: "dontpullup"
        )
    ]
)
