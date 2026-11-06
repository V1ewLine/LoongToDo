import SwiftUI
import TodoCore

struct ToastOverlay: View {
    let message: String?
    let undo: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let message {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Style.accent)
                    Text(message).font(.system(size: 13))
                    if message.contains("可撤销") {
                        Button("撤销", action: undo).buttonStyle(ElasticButtonStyle()).foregroundStyle(Style.accent)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 13).liquidControl()
                    .id(message).transition(Motion.insertion(reduceMotion: reduceMotion))
            }
        }.animation(reduceMotion ? nil : Motion.layout, value: message)
    }
}

struct ProgressBubble: View {
    let completed: Int
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var expanded = false
    @State private var previousCount: Int?

    var body: some View {
        ZStack {
            Circle()
                .fill(Style.orangeTint)
                .overlay(Circle().strokeBorder(Style.orangeFill.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.025), radius: 8, x: 0, y: 4)
            Circle().stroke(Style.accent.opacity(0.08), lineWidth: 5).padding(10)
            Circle().trim(from: 0, to: progress)
                .stroke(Style.orangeFill, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(10)
                .animation(reduceMotion ? nil : Motion.layout, value: progress)
            VStack(spacing: 3) {
                Text("\(completed)").font(.system(size: 30, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText()).foregroundStyle(Style.accent)
                    .animation(reduceMotion ? nil : Motion.layout, value: completed)
                Text("今日完成").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
        }.frame(width: 104, height: 104)
            .scaleEffect(expanded && !reduceMotion ? 1.10 : 1)
            .accessibilityElement(children: .ignore).accessibilityLabel("今日完成 \(completed) 项")
            .task(id: completed) {
                let shouldBounce = previousCount != nil && previousCount != completed
                previousCount = completed
                guard shouldBounce, !reduceMotion else { expanded = false; return }
                withAnimation(Motion.press) { expanded = true }
                do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
                withAnimation(Motion.release) { expanded = false }
            }
    }
}

/// Keep a changed completion state visible briefly; persistence happens immediately in AppStore.
/// The task is cancelled when the user changes filters, searches, or makes another edit.
struct AnimatedTodoList: View {
    @ObservedObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: [Todo]
    @State private var previousFilter: TodoFilter
    @State private var previousSearch: String

    init(store: AppStore) {
        self.store = store
        _displayed = State(initialValue: store.visibleTodos)
        _previousFilter = State(initialValue: store.filter)
        _previousSearch = State(initialValue: store.search)
    }

    private struct Snapshot: Equatable {
        let todos: [Todo]
        let visible: [Todo]
        let filter: TodoFilter
        let search: String
        let reduceMotion: Bool
    }

    var body: some View {
        let snapshot = Snapshot(todos: store.todos, visible: store.visibleTodos, filter: store.filter, search: store.search, reduceMotion: reduceMotion)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if displayed.isEmpty {
                    EmptyTasks(filter: store.filter, searching: !store.search.isEmpty) { store.newTodo() }
                        .frame(maxWidth: .infinity).padding(.vertical, 38)
                        .transition(Motion.insertion(reduceMotion: reduceMotion))
                } else {
                    if store.filter == .today {
                        Text("今天到期、已逾期及未设日期的待办").font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 4).padding(.bottom, 3)
                    }
                    ForEach(displayed) { todo in
                        TodoRow(todo: todo, store: store, now: store.now)
                            .transition(.asymmetric(insertion: Motion.insertion(reduceMotion: reduceMotion), removal: reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity)))
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "leaf").foregroundStyle(Style.accent.opacity(0.7))
                    Text("不必填满每一分钟，做好眼前这一件。")
                }.font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 18).padding(.bottom, 14)
            }.padding(.horizontal, 5).padding(.top, 5)
        }.scrollIndicators(.hidden)
            .task(id: snapshot) {
                let sameContext = previousFilter == snapshot.filter && previousSearch == snapshot.search
                previousFilter = snapshot.filter
                previousSearch = snapshot.search
                let current = Dictionary(uniqueKeysWithValues: snapshot.todos.map { ($0.id, $0) })
                let completionChanged = displayed.contains { old in
                    current[old.id].map { $0.isCompleted != old.isCompleted } ?? false
                }
                if sameContext && completionChanged && !reduceMotion {
                    withAnimation(Motion.press) { displayed = displayed.compactMap { current[$0.id] } }
                    do { try await Task.sleep(for: .milliseconds(320)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                // Filter/search replacements avoid animating every outgoing and incoming row.
                withAnimation(reduceMotion || !sameContext ? nil : Motion.layout) { displayed = snapshot.visible }
            }
    }
}
