// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexQuotaWidget",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexQuotaWidget", targets: ["CodexQuotaDesktop"])],
    targets: [.executableTarget(name: "CodexQuotaDesktop")]
)
