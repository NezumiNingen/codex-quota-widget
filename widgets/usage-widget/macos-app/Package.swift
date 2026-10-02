// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsageWidget",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexUsageWidget", targets: ["CodexQuotaDesktop"])],
    targets: [.executableTarget(name: "CodexQuotaDesktop")]
)
