import PackageDescription

let package = Package(
    name: "SwiftZip",
    dependencies: [
        .Package(url: "https://github.com/iamjono/minizip.git", versions: Version(0,0,0)..<Version(10,0,0))
    ]
)
