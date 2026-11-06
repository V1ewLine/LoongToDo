import AppKit
import Combine
import EventKit
import UserNotifications
import TodoCore

struct CalendarChoice: Identifiable {
    let id: String
    let title: String
    let source: String
    let color: NSColor
}

struct AgendaEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let location: String
    let calendarTitle: String
    let color: NSColor
    let recurring: Bool
}

@MainActor
final class CalendarService: ObservableObject {
    private let store = EKEventStore()
    let isDemo: Bool
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var calendars: [CalendarChoice] = []
    @Published var events: [AgendaEvent] = []
    var defaultCalendarID: String {
        guard isConnected, !isDemo else { return calendars.first?.id ?? "" }
        return store.defaultCalendarForNewEvents?.calendarIdentifier ?? calendars.first?.id ?? ""
    }

    init(isDemo: Bool) { self.isDemo = isDemo }

    func connect(day: Date) async throws {
        guard !isDemo else { refresh(day: day); return }
        isConnecting = true
        defer { isConnecting = false }
        guard try await store.requestFullAccessToEvents() else {
            throw ValidationError("日历访问未获授权。请到系统设置 → 隐私与安全性 → 日历，允许 LoongTodo 访问，然后重试。")
        }
        refresh(day: day)
    }

    func refresh(day: Date) {
        if isDemo {
            isConnected = true
            calendars = [CalendarChoice(id: "demo", title: "个人", source: "预览", color: BrandArtwork.ribbonColor)]
            let start = Calendar.current.startOfDay(for: day)
            events = [
                AgendaEvent(id: "demo1", title: "留一点时间，专注创作", start: start.addingTimeInterval(10 * 3600), end: start.addingTimeInterval(11 * 3600), allDay: false, location: "", calendarTitle: "个人", color: BrandArtwork.ribbonColor, recurring: true),
                AgendaEvent(id: "demo2", title: "出门走走，给灵感充电", start: start.addingTimeInterval(16 * 3600), end: start.addingTimeInterval(16.5 * 3600), allDay: false, location: "公园", calendarTitle: "个人", color: BrandArtwork.foldColor, recurring: false)
            ]
            return
        }
        isConnected = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        guard isConnected else { calendars = []; events = []; return }
        calendars = store.calendars(for: .event).filter(\.allowsContentModifications).map {
            CalendarChoice(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title, color: NSColor(cgColor: $0.cgColor) ?? BrandArtwork.ribbonColor)
        }
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }.enumerated().map { index, event in
            AgendaEvent(id: "\(event.eventIdentifier ?? "event")-\(event.startDate.timeIntervalSince1970)-\(index)",
                        title: event.title ?? "未命名日程", start: event.startDate, end: event.endDate,
                        allDay: event.isAllDay, location: event.location ?? "", calendarTitle: event.calendar.title,
                        color: NSColor(cgColor: event.calendar.cgColor) ?? BrandArtwork.ribbonColor, recurring: event.hasRecurrenceRules)
        }
    }

    func create(_ draft: EventDraft) throws -> String {
        guard !isDemo else { throw ValidationError("预览模式不会写入系统日历。请打开正式应用添加日程。") }
        let validated = try draft.validated()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
              let calendar = store.calendar(withIdentifier: validated.calendarID), calendar.allowsContentModifications else {
            throw ValidationError("此日历不可写入，请重新连接并选择日历。")
        }
        let event = EKEvent(eventStore: store)
        event.title = validated.title; event.notes = validated.notes; event.location = validated.location
        event.startDate = validated.start; event.endDate = validated.end; event.isAllDay = validated.allDay
        event.calendar = calendar; event.timeZone = .current
        if let minutes = validated.alarmMinutes { event.addAlarm(EKAlarm(relativeOffset: -Double(minutes) * 60)) }
        if validated.frequency != .none {
            let frequency: EKRecurrenceFrequency
            switch validated.frequency { case .daily: frequency = .daily; case .weekly: frequency = .weekly; default: frequency = .monthly }
            let end = validated.repeatUntil.map { EKRecurrenceEnd(end: $0) }
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: frequency, interval: validated.interval, end: end))
        }
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private var queue: Task<Void, Never>?
    private let prefix = "loongtodo."
    func start() { UNUserNotificationCenter.current().delegate = self }
    func authorize() async throws {
        guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else {
            throw ValidationError("通知未获授权。请在系统设置 → 通知 → LoongTodo 中允许通知，或将提醒设为“不提醒”。")
        }
    }
    // Serialize full reconciliation so rapid edits/completion cannot leave stale reminders behind.
    func reconcile(_ todos: [Todo], onError: @escaping (String) -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            let delivered = await center.deliveredNotifications()
            let activeIDs = Set(todos.filter { !$0.isCompleted }.map { prefix + $0.id.uuidString })
            center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) && !activeIDs.contains($0) })
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let upcoming = todos.filter { ($0.reminderDate ?? .distantPast) > Date() }.sorted { $0.reminderDate! < $1.reminderDate! }
            for todo in upcoming.prefix(60) {
                guard let date = todo.reminderDate, date > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = todo.title
                content.body = todo.reminderMinutes == 0 ? "待办已到截止时间。" : "待办将在 \(todo.reminderMinutes!) 分钟后截止。"
                content.sound = .default
                content.userInfo = ["todoID": todo.id.uuidString]
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                do { try await center.add(UNNotificationRequest(identifier: prefix + todo.id.uuidString, content: content, trigger: trigger)) }
                catch { onError("待办已保存，但提醒未能安排：\(error.localizedDescription)"); break }
            }
            if upcoming.count > 60 { onError("待办已保存。已安排最近的 60 条提醒；再次打开应用时会补充后续提醒。") }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
        completionHandler()
    }
}
