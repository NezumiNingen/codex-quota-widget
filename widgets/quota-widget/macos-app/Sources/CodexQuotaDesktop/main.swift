import AppKit
import SwiftUI

private struct Snapshot: Codable {
    let remainingPercent: Double
    let period: String?
    let resetAt: String?
    let plan: String?
    let credits: Credits?
    let shortWindow: QuotaWindow?
    let dailyUsage90: [DailyUsage]?
    let recent7: [DailyUsage]?
    let usage: Usage?

    struct QuotaWindow: Codable {
        let remainingPercent: Double
        let period: String?
        let resetAt: String?
    }

    struct Credits: Codable {
        let hasCredits: Bool?
        let unlimited: Bool?
        let balance: String?
    }

    struct Usage: Codable {
        let lifetimeTokens: Int64?
    }

    struct DailyUsage: Codable, Identifiable {
        let date: String
        let tokens: Int64
        var id: String { date }
    }
}

private let previewSnapshot = Snapshot(
    remainingPercent: 0,
    period: nil,
    resetAt: nil,
    plan: nil,
    credits: nil,
    shortWindow: nil,
    dailyUsage90: [],
    recent7: [],
    usage: nil
)

@MainActor
private final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: Snapshot?
    private let liveURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/codex-quota-live.json")

    init() {
        reload()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        guard let data = try? Data(contentsOf: liveURL), let value = try? JSONDecoder().decode(Snapshot.self, from: data) else {
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

    private func shortWindowValue(_ snapshot: Snapshot) -> Double {
        min(max(snapshot.shortWindow?.remainingPercent ?? 0, 0), 100)
    }

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
                Text(snapshot.plan ?? "—")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            HStack(spacing: 18) {
                Ring(value: value, diameter: 145)
                VStack(alignment: .leading, spacing: 12) {
                    Info(title: "周期", value: snapshot.period ?? "—")
                    Divider().overlay(.white.opacity(0.34))
                    Info(title: "重置", value: snapshot.resetAt ?? "—")
                    Divider().overlay(.white.opacity(0.34))
                    Info(title: "点数余额", value: creditBalance(snapshot))
                }
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 7) {
                let shortValue = shortWindowValue(snapshot)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.28))
                        Capsule().fill(LinearGradient(colors: [.green, .mint, .cyan, .blue, .purple], startPoint: .leading, endPoint: .trailing)).frame(width: proxy.size.width * shortValue / 100)
                    }
                }.frame(height: 13)
                HStack {
                    Text(snapshot.shortWindow == nil ? "5小时额度 · 等待同步" : "5小时额度 · \(snapshot.shortWindow?.resetAt ?? "刚刚更新") 重置")
                    Spacer()
                    Text(snapshot.shortWindow == nil ? "—" : "已用 \(Int((100 - shortValue).rounded()))%")
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

private func formatTokens(_ tokens: Int64) -> String {
    let amount = Double(max(0, tokens))
    if amount >= 1_000_000_000 { return String(format: "%.1fB", amount / 1_000_000_000) }
    if amount >= 1_000_000 { return String(format: "%.1fM", amount / 1_000_000) }
    if amount >= 1_000 { return String(format: "%.1fK", amount / 1_000) }
    return "\(tokens)"
}

private func weekdayLabel(_ isoDate: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "zh_CN")
    guard let date = formatter.date(from: isoDate) else { return "·" }
    let labels = ["日", "一", "二", "三", "四", "五", "六"]
    return labels[Calendar.current.component(.weekday, from: date) - 1]
}

private struct GoalRow: View {
    let title: String
    let tokens: Int64
    let goal: Int64

    private var percent: Int {
        guard goal > 0 else { return 0 }
        return Int((Double(tokens) / Double(goal) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title).frame(width: 55, alignment: .leading)
                Text("\(formatTokens(tokens)) / \(formatTokens(goal))")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(percent)%").font(.system(size: 14, weight: .bold))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * min(1, max(0, Double(percent) / 100)))
                }
            }
            .frame(height: 7)
        }
        .foregroundStyle(.white.opacity(0.92))
    }
}

private struct UsageSummaryBlock: View {
    let todayTokens: Int64
    let weekTokens: Int64
    let totalTokens: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Label("Token 使用量", systemImage: "chart.bar.fill")
                    .font(.system(size: 17, weight: .bold))
            }
            UsageRow(title: "今天", value: todayTokens)
            UsageRow(title: "本周", value: weekTokens)
            UsageRow(title: "总使用量", value: totalTokens)
        }
    }
}

private struct UsageRow: View {
    let title: String
    let value: Int64

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .frame(width: 55, alignment: .leading)
            Text(formatTokens(value))
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.92))
    }
}

private struct RecentUsageChart: View {
    let entries: [Snapshot.DailyUsage]

    private var values: [Snapshot.DailyUsage] { Array(entries.suffix(7)) }
    private var total: Int64 { values.reduce(0) { $0 + $1.tokens } }
    private var maximum: Double { max(Double(values.map(\.tokens).max() ?? 1), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("最近 7 日", systemImage: "chart.xyaxis.line")
                .font(.system(size: 16, weight: .bold))
            GeometryReader { proxy in
                let points = chartPoints(in: proxy.size)
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.black.opacity(0.08))
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(LinearGradient(colors: [.pink, .white], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    ForEach(Array(points.enumerated()), id: \.offset) { item in
                        Circle().fill(.white).frame(width: 5, height: 5).position(item.element)
                    }
                }
            }
            .frame(height: 76)
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { item in
                    Text(weekdayLabel(item.element.date))
                        .font(.system(size: 9, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
            }
            Text("Token 总量 \(formatTokens(total))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let width = max(size.width - 10, 1)
        let height = max(size.height - 10, 1)
        let denominator = max(values.count - 1, 1)
        return values.enumerated().map { index, item in
            CGPoint(
                x: 5 + width * CGFloat(index) / CGFloat(denominator),
                y: 5 + height * (1 - CGFloat(Double(item.tokens) / maximum))
            )
        }
    }
}

private struct UsageHeatmap: View {
    let entries: [Snapshot.DailyUsage]
    @State private var hoveredDate: String?
    @State private var selectedDate: String?

    private var values: [Snapshot.DailyUsage] {
        Array(entries.suffix(90))
    }
    private var maximum: Double {
        let raw = values.map(\.tokens)
        return max(Double(raw.max() ?? 1), 1)
    }
    private let cellStride: CGFloat = 15

    private var focusedEntry: Snapshot.DailyUsage? {
        let date = hoveredDate ?? selectedDate
        guard let date else { return nil }
        return values.first(where: { $0.date == date })
    }

    private var weeks: [[Snapshot.DailyUsage]] {
        guard let first = values.first,
              let firstDate = isoDate(first.date),
              let last = values.last,
              let lastDate = isoDate(last.date) else {
            return Array(repeating: Array(repeating: Snapshot.DailyUsage(date: "", tokens: 0), count: 7), count: 13)
        }
        let calendar = Calendar.current
        let mondayOffset = (calendar.component(.weekday, from: firstDate) + 5) % 7
        guard let start = calendar.date(byAdding: .day, value: -mondayOffset, to: firstDate) else { return [] }
        let days = calendar.dateComponents([.day], from: start, to: lastDate).day ?? 0
        let weekCount = max(1, days / 7 + 1)
        let byDate = Dictionary(uniqueKeysWithValues: values.map { ($0.date, $0.tokens) })
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return (0..<weekCount).map { week in
            (0..<7).map { weekday in
                let offset = week * 7 + weekday
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                    return Snapshot.DailyUsage(date: "", tokens: 0)
                }
                let label = formatter.string(from: date)
                return Snapshot.DailyUsage(date: label, tokens: byDate[label] ?? 0)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("近 90 天用量", systemImage: "calendar")
                    .font(.system(size: 16, weight: .bold))
                Spacer(minLength: 3)
                if let focusedEntry {
                    Text("\(displayDate(focusedEntry.date)) · \(formatTokens(focusedEntry.tokens)) Token")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.16), in: Capsule())
                }
            }
            HStack(spacing: 3) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { week in
                    VStack(spacing: 2) {
                        ForEach(Array(week.element.enumerated()), id: \.offset) { day in
                            HeatmapCell(
                                item: day.element,
                                visible: isVisibleDate(day.element),
                                color: cellColor(Double(day.element.tokens)),
                                hoveredDate: $hoveredDate,
                                selectedDate: $selectedDate
                            )
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                    Text(showMonthLabel(at: item.offset) ? monthLabel(for: item.element.first?.date) : "")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: cellStride, alignment: .leading)
                }
            }
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    private func cellColor(_ tokens: Double) -> Color {
        guard tokens > 0 else { return Color.white.opacity(0.055) }
        let ratio = min(1, max(0, tokens / maximum))
        let visibleLevel = max(0.26, pow(ratio, 0.42))
        return Color(red: 0.12 + 0.20 * visibleLevel,
                     green: 0.20 + 0.36 * visibleLevel,
                     blue: 0.34 + 0.56 * visibleLevel)
            .opacity(0.58 + 0.38 * visibleLevel)
    }

    private func isVisibleDate(_ item: Snapshot.DailyUsage) -> Bool {
        guard let first = values.first?.date,
              let last = values.last?.date,
              !item.date.isEmpty else { return false }
        return item.date >= first && item.date <= last
    }

    private func monthLabel(for date: String?) -> String {
        guard let date, let value = isoDate(date) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: value)
    }

    private func showMonthLabel(at index: Int) -> Bool {
        guard index == 0 else {
            guard let current = weeks[index].first?.date,
                  let previous = weeks[index - 1].first?.date,
                  let currentDate = isoDate(current),
                  let previousDate = isoDate(previous) else { return false }
            return Calendar.current.component(.month, from: currentDate) != Calendar.current.component(.month, from: previousDate)
        }
        return true
    }
}

private struct HeatmapCell: View {
    let item: Snapshot.DailyUsage
    let visible: Bool
    let color: Color
    @Binding var hoveredDate: String?
    @Binding var selectedDate: String?
    @State private var isHovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(visible ? color : .clear)
            .contentShape(Rectangle())
            .overlay {
                if visible && isHovering {
                    Text("\(formatTokens(item.tokens)) Token")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .fixedSize()
                        .offset(y: -23)
                        .zIndex(20)
                }
            }
            .onHover { hovering in
                guard visible else { return }
                isHovering = hovering
                hoveredDate = hovering ? item.date : nil
            }
            .onContinuousHover { phase in
                guard visible else { return }
                switch phase {
                case .active:
                    isHovering = true
                    hoveredDate = item.date
                case .ended:
                    isHovering = false
                    if hoveredDate == item.date { hoveredDate = nil }
                }
            }
            .onTapGesture {
                guard visible else { return }
                selectedDate = item.date
            }
            .help(visible ? "\(displayDate(item.date)) · \(formatTokens(item.tokens)) Token" : "")
    }
}

private func isoDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.date(from: value)
}

private func displayDate(_ value: String) -> String {
    guard let date = isoDate(value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日"
    return formatter.string(from: date)
}

private struct InsightsPanelView: View {
    @StateObject private var store = QuotaStore()
    private var displayedSnapshot: Snapshot { store.snapshot ?? previewSnapshot }

    private var daily: [Snapshot.DailyUsage] { displayedSnapshot.dailyUsage90 ?? [] }
    private var recent: [Snapshot.DailyUsage] { displayedSnapshot.recent7 ?? Array(daily.suffix(7)) }

    private var todayTokens: Int64 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return daily.last(where: { $0.date == formatter.string(from: Date()) })?.tokens ?? recent.last?.tokens ?? 0
    }

    private var weekTokens: Int64 {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let mondayString = formatter.string(from: monday)
        return daily.filter { $0.date >= mondayString }.reduce(0) { $0 + $1.tokens }
    }

    private var totalTokens: Int64 {
        displayedSnapshot.usage?.lifetimeTokens ?? daily.reduce(0) { $0 + $1.tokens }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            UsageSummaryBlock(todayTokens: todayTokens, weekTokens: weekTokens, totalTokens: totalTokens)
                .frame(width: 150, alignment: .leading)
            RecentUsageChart(entries: recent)
                .frame(width: 150, alignment: .leading)
            UsageHeatmap(entries: daily)
                .frame(width: 212, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(width: 578, height: 180, alignment: .topLeading)
        .background {
            ZStack {
                VisualEffect()
                Color(red: 0.48, green: 0.49, blue: 0.50).opacity(0.68)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.24), lineWidth: 1))
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private enum WidgetMode {
        case quota
        case usage
    }

    private var panel: NSPanel?
    private var insightsPanel: NSPanel?
    private let positionKey = "CodexQuotaDesktop.position"
    private let insightsPositionKey = "CodexQuotaInsights.position"
    private var moveMode = true
    private var insightsMoveMode = true
    private var lockTimer: Timer?
    private var insightsLockTimer: Timer?
    private let mode: WidgetMode

    override init() {
        mode = CommandLine.arguments.contains("--usage") ? .usage : .quota
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        switch mode {
        case .quota:
            createQuotaPanel()
        case .usage:
            createInsightsPanel()
        }
    }

    private func createQuotaPanel() {
        let content = NSHostingView(rootView: DesktopCard())
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 250), styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
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
        guard let movedWindow = notification.object as? NSPanel else { return }
        if movedWindow === panel {
            UserDefaults.standard.set(NSStringFromPoint(movedWindow.frame.origin), forKey: positionKey)
            guard moveMode else { return }
            lockTimer?.invalidate()
            lockTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.lockToDesktop()
            }
        } else if movedWindow === insightsPanel {
            UserDefaults.standard.set(NSStringFromPoint(movedWindow.frame.origin), forKey: insightsPositionKey)
            guard insightsMoveMode else { return }
            insightsLockTimer?.invalidate()
            insightsLockTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.lockInsightsToDesktop()
            }
        }
    }

    private func lockToDesktop() {
        guard moveMode, let panel else { return }
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        moveMode = false
    }

    private func createInsightsPanel() {
        let content = NSHostingView(rootView: InsightsPanelView())
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 578, height: 180), styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        if let saved = UserDefaults.standard.string(forKey: insightsPositionKey) {
            panel.setFrameOrigin(NSPointFromString(saved))
        } else if let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.minX + 72, y: visible.minY + 86))
        } else {
            panel.setFrameOrigin(NSPoint(x: 72, y: 86))
        }
        panel.orderFrontRegardless()
        insightsPanel = panel
        insightsLockTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self] _ in
            self?.lockInsightsToDesktop()
        }
    }

    private func lockInsightsToDesktop() {
        guard insightsMoveMode, let insightsPanel else { return }
        insightsPanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        insightsMoveMode = false
    }
}

@main
private struct CodexQuotaDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}
