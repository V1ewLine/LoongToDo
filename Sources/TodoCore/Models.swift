import Foundation

public enum Priority: String, Codable, CaseIterable, Sendable {
    case normal, important
    public var title: String { self == .normal ? "普通" : "重要" }
}

public struct Todo: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var createdAt: Date
    public var dueDate: Date?
    public var reminderMinutes: Int?
    public var priority: Priority
    public var completedAt: Date?
    public var calendarEventID: String?
    public var isCompleted: Bool { completedAt != nil }
    public var reminderDate: Date? {
        guard !isCompleted, let dueDate, let reminderMinutes else { return nil }
        return dueDate.addingTimeInterval(-Double(reminderMinutes) * 60)
    }

    public init(id: UUID = UUID(), title: String, notes: String = "", createdAt: Date = Date(), dueDate: Date? = nil,
                reminderMinutes: Int? = nil, priority: Priority = .normal, completedAt: Date? = nil, calendarEventID: String? = nil) {
        self.id = id; self.title = title; self.notes = notes; self.createdAt = createdAt
        self.dueDate = dueDate; self.reminderMinutes = reminderMinutes; self.priority = priority
        self.completedAt = completedAt; self.calendarEventID = calendarEventID
    }
    public func validated() throws -> Todo {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.title.isEmpty else { throw ValidationError("请填写待办标题。") }
        guard copy.title.count <= 200 else { throw ValidationError("标题请控制在 200 个字以内。") }
        if let minutes = reminderMinutes, minutes < 0 { throw ValidationError("提醒时间不能晚于截止时间。") }
        if dueDate == nil { copy.reminderMinutes = nil }
        return copy
    }
}

public enum TodoFilter: String, CaseIterable, Identifiable {
    case today, all, upcoming, completed, calendar
    public var id: String { rawValue }
    public var title: String {
        switch self { case .today: return "今天"; case .all: return "全部待办"; case .upcoming: return "未来七天"; case .completed: return "已完成"; case .calendar: return "日历日程" }
    }
    public var symbol: String {
        switch self { case .today: return "sun.max"; case .all: return "square.stack.3d.up"; case .upcoming: return "calendar.badge.clock"; case .completed: return "checkmark.circle"; case .calendar: return "calendar" }
    }
    public func includes(_ todo: Todo, now: Date, calendar: Calendar = .current) -> Bool {
        if self == .completed { return todo.isCompleted }
        guard !todo.isCompleted else { return false }
        switch self {
        case .all: return true
        case .today:
            guard let due = todo.dueDate else { return true }
            return due < calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        case .upcoming:
            guard let due = todo.dueDate else { return false }
            let start = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return due >= start && due < end
        default: return false
        }
    }
}

public enum RepeatFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, daily, weekly, monthly
    public var id: String { rawValue }
    public var title: String {
        switch self { case .none: return "不重复"; case .daily: return "每天"; case .weekly: return "每周"; case .monthly: return "每月" }
    }
    public var unit: String {
        switch self { case .none: return "次"; case .daily: return "天"; case .weekly: return "周"; case .monthly: return "个月" }
    }
}

public struct EventDraft: Sendable {
    public var title = ""
    public var notes = ""
    public var location = ""
    public var start: Date
    public var end: Date
    public var allDay = false
    public var calendarID = ""
    public var frequency: RepeatFrequency = .none
    public var interval = 1
    public var repeatUntil: Date?
    public var alarmMinutes: Int?
    public init(now: Date = Date()) {
        let rounded = Date(timeIntervalSince1970: ceil(now.timeIntervalSince1970 / 1800) * 1800)
        start = rounded; end = rounded.addingTimeInterval(3600)
    }
    public func validated(calendar: Calendar = .current) throws -> EventDraft {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.title.isEmpty else { throw ValidationError("请填写日程标题。") }
        guard !calendarID.isEmpty else { throw ValidationError("请选择可写入的日历。") }
        if allDay {
            guard calendar.startOfDay(for: end) >= calendar.startOfDay(for: start) else { throw ValidationError("结束日期不能早于开始日期。") }
            copy.start = calendar.startOfDay(for: start)
            // The form uses inclusive dates; EventKit uses an exclusive end for all-day events.
            copy.end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
        } else if end <= start { throw ValidationError("结束时间必须晚于开始时间。") }
        guard (1...99).contains(interval) else { throw ValidationError("重复间隔应为 1–99。") }
        if frequency != .none, let until = repeatUntil {
            guard calendar.startOfDay(for: until) >= calendar.startOfDay(for: start) else { throw ValidationError("重复结束日期不能早于首次日程。") }
            copy.repeatUntil = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: until))!.addingTimeInterval(-1)
        }
        return copy
    }
}

public struct ValidationError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct TodoRepository {
    public let url: URL
    public init(url: URL) { self.url = url }
    private struct Document: Codable { var version: Int; var todos: [Todo] }
    public func load() throws -> [Todo] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let doc = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        guard doc.version == 1 else { throw ValidationError("数据版本暂不支持，请保留原文件并升级应用。") }
        guard Set(doc.todos.map(\.id)).count == doc.todos.count else { throw ValidationError("数据包含重复标识，已停止写入以保护原文件。") }
        return doc.todos
    }
    public func save(_ todos: [Todo]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Document(version: 1, todos: todos))
        try data.write(to: url, options: .atomic)
    }
}
