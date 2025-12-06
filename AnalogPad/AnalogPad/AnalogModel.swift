import Combine
import SwiftUI

enum CardTab: String, CaseIterable, Identifiable, Codable {
    case today, next, someday

    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: return "Today"
        case .next: return "Next"
        case .someday: return "Someday"
        }
    }

    var subtitle: String {
        switch self {
        case .today: return "Up to 10 tasks to focus on now"
        case .next: return "Queue for what comes soon"
        case .someday: return "Ideas and long bets"
        }
    }

    var accent: Color {
        switch self {
        case .today: return .orange
        case .next: return .blue
        case .someday: return .purple
        }
    }
}

enum TaskSignal: String, CaseIterable, Identifiable, Codable {
    case empty
    case inProgress
    case delegated
    case done
    case canceled

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .empty: return "circle"
        case .inProgress: return "circle.dotted"
        case .delegated: return "arrowshape.turn.up.right"
        case .done: return "checkmark.circle.fill"
        case .canceled: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .empty: return .secondary
        case .inProgress: return .yellow
        case .delegated: return .blue
        case .done: return .green
        case .canceled: return .red
        }
    }

    var label: String {
        switch self {
        case .empty: return "Unmarked"
        case .inProgress: return "In progress"
        case .delegated: return "Delegated"
        case .done: return "Completed"
        case .canceled: return "Canceled"
        }
    }

    func next() -> TaskSignal {
        switch self {
        case .empty: return .inProgress
        case .inProgress: return .delegated
        case .delegated: return .done
        case .done: return .empty
        case .canceled: return .empty
        }
    }
}

struct TaskItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var signal: TaskSignal
    var assignee: String?
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        signal: TaskSignal = .empty,
        assignee: String? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.signal = signal
        self.assignee = assignee
        self.note = note
        self.createdAt = createdAt
    }
}

struct AnalogCard: Identifiable, Codable {
    let id: UUID
    var tab: CardTab
    var title: String
    var subtitle: String
    var date: Date
    var dots: Int
    var tasks: [TaskItem]
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        tab: CardTab,
        title: String,
        subtitle: String = "",
        date: Date = Date(),
        dots: Int = 0,
        tasks: [TaskItem] = [],
        isArchived: Bool = false
    ) {
        self.id = id
        self.tab = tab
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.dots = dots
        self.tasks = tasks
        self.isArchived = isArchived
    }
}

@MainActor
final class AnalogBoardModel: ObservableObject {
    @Published private(set) var activeCards: [CardTab: AnalogCard]
    @Published private(set) var archive: [AnalogCard]
    @Published var selectedTab: CardTab = .today
    @Published var focusMode = false

    private let todayLimit = 10
    private let storage: AnalogBoardStorage

    init(
        activeCards: [CardTab: AnalogCard]? = nil,
        archive: [AnalogCard] = [],
        storage: AnalogBoardStorage? = nil
    ) {
        self.storage = storage ?? AnalogBoardStorage()

        if let activeCards {
            self.activeCards = activeCards
            self.archive = archive
        } else if let saved = storage?.load() {
            self.activeCards = saved.activeCards
            self.archive = saved.archive
            self.selectedTab = saved.selectedTab
        } else if let saved = self.storage.load() {
            self.activeCards = saved.activeCards
            self.archive = saved.archive
            self.selectedTab = saved.selectedTab
        } else {
            let sample = AnalogBoardModel.sampleData()
            self.activeCards = sample.active
            self.archive = sample.archive
        }
    }

    func card(for tab: CardTab) -> AnalogCard {
        activeCards[tab] ?? AnalogCard(tab: tab, title: tab.title, subtitle: tab.subtitle)
    }

    func setDots(for tab: CardTab, to value: Int) {
        var card = card(for: tab)
        card.dots = max(0, min(value, 3))
        updateCard(card)
    }

    @discardableResult
    func addTask(_ text: String, to tab: CardTab) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if tab == .today && card(for: tab).tasks.count >= todayLimit {
            return false
        }

        var card = card(for: tab)
        card.tasks.append(TaskItem(text: trimmed))
        updateCard(card)
        return true
    }

    func toggleSignal(taskID: UUID, in tab: CardTab) {
        updateTask(taskID, in: tab) { item in
            item.signal = item.signal.next()
        }
    }

    func setSignal(_ signal: TaskSignal, for taskID: UUID, in tab: CardTab) {
        updateTask(taskID, in: tab) { item in
            item.signal = signal
        }
    }

    @discardableResult
    func moveTask(_ taskID: UUID, from source: CardTab, to destination: CardTab) -> Bool {
        if destination == .today && card(for: destination).tasks.count >= todayLimit {
            return false
        }

        guard var sourceCard = activeCards[source],
              let index = sourceCard.tasks.firstIndex(where: { $0.id == taskID }) else { return false }

        let task = sourceCard.tasks.remove(at: index)
        activeCards[source] = sourceCard

        var destinationCard = card(for: destination)
        var resetTask = task
        if destination != source {
            resetTask.signal = .empty
        }
        destinationCard.tasks.append(resetTask)
        updateCard(destinationCard)
        return true
    }

    func closeToday(moveIncompleteToNext: Bool = true) {
        guard var todayCard = activeCards[.today] else { return }
        todayCard.isArchived = true
        archive.insert(todayCard, at: 0)

        let unfinished = todayCard.tasks.filter { $0.signal != .done }
        var nextCard = card(for: .next)
        if moveIncompleteToNext {
            for var task in unfinished {
                task.signal = .inProgress
                nextCard.tasks.append(task)
            }
        }

        activeCards[.today] = AnalogCard(tab: .today, title: "Today", subtitle: todayCard.subtitle)
        updateCard(nextCard)
    }

    func removeTask(_ taskID: UUID, from tab: CardTab) {
        guard var card = activeCards[tab] else { return }
        card.tasks.removeAll { $0.id == taskID }
        updateCard(card)
    }

    var todayCapacityText: String {
        let count = card(for: .today).tasks.count
        return "\(count)/\(todayLimit) slots used"
    }

    func persist() {
        let state = AnalogBoardState(activeCards: activeCards, archive: archive, selectedTab: selectedTab)
        storage.save(state)
    }
}

extension AnalogBoardModel {
    private func updateCard(_ card: AnalogCard) {
        activeCards[card.tab] = card
        persist()
    }

    private func updateTask(_ taskID: UUID, in tab: CardTab, transform: (inout TaskItem) -> Void) {
        guard var card = activeCards[tab],
              let index = card.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        transform(&card.tasks[index])
        updateCard(card)
    }

    static func sampleData() -> (active: [CardTab: AnalogCard], archive: [AnalogCard]) {
        let today = AnalogCard(
            tab: .today,
            title: "Today",
            subtitle: "Ship 1–3 things that matter",
            dots: 2,
            tasks: [
                TaskItem(text: "Draft Analog app structure", signal: .inProgress),
                TaskItem(text: "Pull 3 tasks from Next", signal: .delegated),
                TaskItem(text: "Block 90 mins focus session", signal: .empty)
            ]
        )

        let next = AnalogCard(
            tab: .next,
            title: "Next",
            subtitle: "Important but not forced into today",
            tasks: [
                TaskItem(text: "Sketch UI for Focus mode"),
                TaskItem(text: "Define sync model with iCloud Drive"),
                TaskItem(text: "Prep export to PDF/Markdown", signal: .inProgress),
                TaskItem(text: "Research haptics/animation cues", signal: .delegated)
            ]
        )

        let someday = AnalogCard(
            tab: .someday,
            title: "Someday",
            subtitle: "Ideas and long bets",
            tasks: [
                TaskItem(text: "Add hand-drawn texture pack"),
                TaskItem(text: "Explore Apple Pencil OCR for tasks"),
                TaskItem(text: "Try linked cards for projects")
            ]
        )

        let archived = AnalogCard(
            tab: .today,
            title: "Today",
            subtitle: "Yesterday",
            date: Date().addingTimeInterval(-86_400),
            dots: 3,
            tasks: [
                TaskItem(text: "Storyboard onboarding", signal: .done),
                TaskItem(text: "Write prompt for Cursor", signal: .done),
                TaskItem(text: "Refine card divider concept", signal: .done)
            ],
            isArchived: true
        )

        return (
            [.today: today, .next: next, .someday: someday],
            [archived]
        )
    }
}
