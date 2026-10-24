// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "DecryptStore", platforms: [.macOS(.v26)], products: [.executable(name: "DecryptStore", targets: ["DecryptStore"])], targets: [.executableTarget(name: "DecryptStore"), .testTarget(name: "DecryptStoreTests", dependencies: ["DecryptStore"])], swiftLanguageModes: [.v5])
