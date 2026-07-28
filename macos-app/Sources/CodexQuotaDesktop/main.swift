import AppKit
import SwiftUI

private struct Snapshot: Codable {
    let remainingPercent: Double
    let period: String?
    let resetAt: String?
    let plan: String?
    let credits: Credits?

    struct Credits: Codable {
        let hasCredits: Bool?
        let unlimited: Bool?
        let balance: String?
    }
}

private let previewSnapshot = Snapshot(
    remainingPercent: 87,
    period: "1周",
    resetAt: "7月25日 11:24",
    plan: "PRO",
    credits: .init(hasCredits: true, unlimited: false, balance: "2.28")
)

@MainActor
private final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: Snapshot?
    private let liveURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/codex-quota-live.json")
    private let fallbackURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/codex-quota.json")

    init() {
        reload()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        let url = FileManager.default.fileExists(atPath: liveURL.path) ? liveURL : fallbackURL
        guard let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            snapshot = nil
            return
        }
        snapshot = value
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private struct Ring: View {
    let value: Double
    let diameter: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.30), lineWidth: diameter * 0.095)
            Circle()
                .trim(from: 0.006, to: max(0.01, min(value / 100, 1)))
                .stroke(AngularGradient(colors: [.purple, .indigo, .blue, .cyan, .mint, .green], center: .center), style: StrokeStyle(lineWidth: diameter * 0.095, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: .cyan.opacity(0.35), radius: diameter * 0.04)
            VStack(spacing: 0) {
                Text(value == floor(value) ? "\(Int(value))%" : String(format: "%.1f%%", value))
                    .font(.system(size: diameter * 0.25, weight: .bold))
                Text("剩余").font(.system(size: diameter * 0.09, weight: .medium)).foregroundStyle(.black.opacity(0.52))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct Info: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.black.opacity(0.42))
            Text(value).font(.system(size: 22, weight: .semibold)).foregroundStyle(.black.opacity(0.86))
        }
    }
}

private struct DesktopCard: View {
    @StateObject private var store = QuotaStore()
    private var displayedSnapshot: Snapshot { store.snapshot ?? previewSnapshot }
    private var value: Double { min(max(displayedSnapshot.remainingPercent, 0), 100) }

    private func creditBalance(_ snapshot: Snapshot) -> String {
        guard snapshot.credits?.hasCredits == true,
              snapshot.credits?.unlimited != true,
              let rawBalance = snapshot.credits?.balance,
              let balance = Decimal(string: rawBalance) else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSDecimalNumber(decimal: balance)) ?? "—") 点"
    }

    var body: some View {
        quota(displayedSnapshot)
        .frame(width: 368, height: 368)
        .scaleEffect(0.68, anchor: .topLeading)
        .frame(width: 250, height: 250, alignment: .topLeading)
    }

    private func quota(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Codex 余量")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Text(snapshot.plan ?? "PLUS")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            HStack(spacing: 18) {
                Ring(value: value, diameter: 145)
                VStack(alignment: .leading, spacing: 12) {
                    Info(title: "周期", value: snapshot.period ?? "1周")
                    Divider().overlay(.white.opacity(0.34))
                    Info(title: "重置", value: snapshot.resetAt ?? "未设置")
                    Divider().overlay(.white.opacity(0.34))
                    Info(title: "点数余额", value: creditBalance(snapshot))
                }
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 7) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.28))
                        Capsule().fill(LinearGradient(colors: [.green, .mint, .cyan, .blue, .purple], startPoint: .leading, endPoint: .trailing)).frame(width: proxy.size.width * value / 100)
                    }
                }.frame(height: 13)
                HStack {
                    Text("刚刚更新")
                    Spacer()
                    Text("已用 \(Int((100 - value).rounded()))%")
                }.font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(24)
        .background {
            ZStack {
                VisualEffect()
                Color(red: 0.48, green: 0.49, blue: 0.50).opacity(0.68)
            }
            .clipShape(RoundedRectangle(cornerRadius: 58, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 58, style: .continuous).stroke(.white.opacity(0.24), lineWidth: 1))
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: NSPanel?
    private let positionKey = "CodexQuotaDesktop.position"
    private var moveMode = true
    private var lockTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let content = NSHostingView(rootView: DesktopCard())
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 250), styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Start in a temporary movable layer. After the first drag, it returns
        // to the desktop layer so it does not cover normal app windows.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        if let saved = UserDefaults.standard.string(forKey: positionKey) {
            panel.setFrameOrigin(NSPointFromString(saved))
        } else {
            panel.center()
        }
        panel.orderFrontRegardless()
        self.panel = panel
        lockTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self] _ in
            self?.lockToDesktop()
        }
    }

    func windowDidMove(_ notification: Notification) {
        if let panel { UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: positionKey) }
        guard moveMode else { return }
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.lockToDesktop()
        }
    }

    private func lockToDesktop() {
        guard moveMode, let panel else { return }
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        moveMode = false
    }
}

@main
private struct CodexQuotaDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}
