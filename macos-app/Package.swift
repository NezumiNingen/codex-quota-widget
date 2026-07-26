// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexQuotaDesktop",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexQuotaDesktop", targets: ["CodexQuotaDesktop"])],
    targets: [.executableTarget(name: "CodexQuotaDesktop")]
)
