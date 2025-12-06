//
//  ContentView.swift
//  AnalogPad
//
//  Created by Aditya Dobriyal on 10/3/25.
//

import SwiftUI
import UniformTypeIdentifiers

private struct TaskDragPayload: Hashable {
    let taskID: UUID
    let source: CardTab

    init?(raw: String) {
        let parts = raw.split(separator: "|")
        guard parts.count == 2,
              let id = UUID(uuidString: String(parts[0])),
              let source = CardTab(rawValue: String(parts[1])) else {
            return nil
        }
        self.taskID = id
        self.source = source
    }

    var rawString: String {
        "\(taskID.uuidString)|\(source.rawValue)"
    }
}

struct ContentView: View {
    @StateObject private var model = AnalogBoardModel()
    @State private var sidebarMoveLimitAlert = false
    @State private var sidebarWidth: CGFloat = 260

    enum SidebarDisplayMode {
        case full
        case compact
        case initials
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 80, ideal: 200, max: 240)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: model.selectedTab, initial: false) { _, _ in
            model.persist()
        }
        .alert("Can't move to Today", isPresented: $sidebarMoveLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Today already has 10 tasks. Clear a slot before promoting more.")
        }
    }

    private var sidebar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let displayMode = sidebarDisplayMode(for: width)

            List {
                Section("Stacks") {
                    ForEach(CardTab.allCases) { tab in
                        sidebarRow(for: tab, displayMode: displayMode)
                    }
                }

                if !model.archive.isEmpty {
                    Section("Archive") {
                        ForEach(model.archive.prefix(5)) { card in
                            ArchiveRow(card: card)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .environment(\.defaultMinListRowHeight, 40)
            .onChange(of: width) { _, newWidth in
                sidebarWidth = newWidth
            }
        }
    }

    private func sidebarDisplayMode(for width: CGFloat) -> SidebarDisplayMode {
        if width < 150 {
            return SidebarDisplayMode.initials
        } else if width < 230 {
            return SidebarDisplayMode.compact
        } else {
            return SidebarDisplayMode.full
        }
    }

    private func sidebarRow(for tab: CardTab, displayMode: SidebarDisplayMode) -> some View {
        let card = model.card(for: tab)
        let isSelected = tab == model.selectedTab
        let onDrop: (TaskDragPayload) -> Bool = { payload in
            let moved = model.moveTask(payload.taskID, from: payload.source, to: tab)
            if !moved, tab == .today {
                sidebarMoveLimitAlert = true
            }
            return moved
        }
        return SidebarRow(
            tab: tab,
            card: card,
            isSelected: isSelected,
            onCloseToday: tab == .today ? { model.closeToday() } : nil,
            onDrop: onDrop,
            displayMode: displayMode
        )
        .onTapGesture { model.selectedTab = tab }
    }

    private var detail: some View {
        let tab = model.selectedTab
        let card = model.card(for: tab)
        let isTodayFull = tab == .today && card.tasks.count >= 10

        return CardDetailView(
            card: card,
            focusMode: $model.focusMode,
            capacityText: model.todayCapacityText,
            isTodayFull: isTodayFull,
            onAddTask: { text in model.addTask(text, to: tab) },
            onToggleSignal: { id in model.toggleSignal(taskID: id, in: tab) },
            onSetSignal: { id, signal in model.setSignal(signal, for: id, in: tab) },
            onMove: { id, destination in model.moveTask(id, from: tab, to: destination) },
            onDropMove: { payload, destination in model.moveTask(payload.taskID, from: payload.source, to: destination) },
            onDelete: { id in model.removeTask(id, from: tab) },
            onDotsChange: { value in model.setDots(for: tab, to: value) },
            onCloseToday: { model.closeToday() }
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct SidebarRow: View {
    let tab: CardTab
    let card: AnalogCard
    let isSelected: Bool
    var onCloseToday: (() -> Void)?
    var onDrop: ((TaskDragPayload) -> Bool)?
    let displayMode: ContentView.SidebarDisplayMode

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(tab.accent.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(Text(tab.title.prefix(1)).font(.headline))
            if displayMode != .initials {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tab.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    if displayMode == .full {
                        Text(card.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if displayMode != .initials {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(card.tasks.count)")
                        .font(.headline)
                    if tab == .today && displayMode == .full {
                        ProgressView(value: Double(card.tasks.filter { $0.signal == .done }.count), total: 10)
                            .progressViewStyle(.linear)
                            .frame(width: 80)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(tab.accent.opacity(isSelected ? 0.12 : 0))
        )
        .swipeActions {
            if tab == .today, let onCloseToday {
                Button("Close Day") {
                    onCloseToday()
                }
                .tint(.orange)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first,
                  let payload = TaskDragPayload(raw: raw) else { return false }
            return onDrop?(payload) ?? false
        }
    }
}

private struct ArchiveRow: View {
    let card: AnalogCard

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.date, format: .dateTime.month().day().year())
                    .font(.subheadline)
                Text("\(card.tasks.count) tasks · \(card.dots) dots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    Circle()
                        .fill(index <= card.dots ? Color.orange : Color.gray.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

private struct CardDetailView: View {
    let card: AnalogCard
    @Binding var focusMode: Bool
    let capacityText: String
    let isTodayFull: Bool
    let onAddTask: (String) -> Bool
    let onToggleSignal: (UUID) -> Void
    let onSetSignal: (UUID, TaskSignal) -> Void
    let onMove: (UUID, CardTab) -> Bool
    let onDropMove: (TaskDragPayload, CardTab) -> Bool
    let onDelete: (UUID) -> Void
    let onDotsChange: (Int) -> Void
    let onCloseToday: () -> Void

    @State private var draft = ""
    @State private var showLimit = false
    @State private var showMoveLimit = false
    @FocusState private var isTyping: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CardHeaderView(card: card, onDotsChange: onDotsChange)

                if card.tab == .today {
                    Text(capacityText)
                        .font(.caption)
                        .foregroundStyle(isTodayFull ? Color.red : .secondary)
                } else {
                    Text(card.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if card.tasks.isEmpty {
                    placeholder
                } else {
                    VStack(spacing: 10) {
                        ForEach(card.tasks) { task in
                            TaskRow(
                                task: task,
                                tab: card.tab,
                                focusMode: focusMode,
                                onToggle: { onToggleSignal(task.id) },
                                onSetSignal: { signal in onSetSignal(task.id, signal) },
                                onMove: { destination in
                                    let moved = onMove(task.id, destination)
                                    if !moved {
                                        showMoveLimit = true
                                    }
                                },
                                onDelete: { onDelete(task.id) }
                            )
                        }
                    }
                }

                addTaskField
            }
            .padding()
            .padding(.horizontal)
        }
        .background(Color.groupedBackground)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first,
                  let payload = TaskDragPayload(raw: raw) else { return false }
            let moved = onDropMove(payload, card.tab)
            if !moved, card.tab == .today {
                showMoveLimit = true
            }
            return moved
        }
        .navigationTitle(card.title)
        .toolbar {
#if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                focusAndCloseButtons
            }
#else
            ToolbarItemGroup {
                focusAndCloseButtons
            }
#endif
        }
        .alert("Today is full", isPresented: $showLimit) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You already have 10 tasks in Today. Finish or move one before adding more.")
        }
        .alert("Can't move to Today", isPresented: $showMoveLimit) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Today already has 10 tasks. Clear a slot before promoting more.")
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No tasks yet")
                .font(.headline)
            Text("Add a few items or pull from another stack to get rolling.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondaryGroupedBackground))
    }

    private var addTaskField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a task")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField("Type task and hit return", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTyping)
                    .onSubmit(addTask)

                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func addTask() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let didAdd = onAddTask(draft)
        if didAdd {
            draft = ""
            isTyping = true
        } else if card.tab == .today {
            showLimit = true
        }
    }

    private var focusAndCloseButtons: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    focusMode.toggle()
                }
            } label: {
                Label("Focus mode", systemImage: focusMode ? "viewfinder.circle.fill" : "viewfinder.circle")
            }

            if card.tab == .today {
                Button("Close Day") {
                    onCloseToday()
                }
            }
        }
    }
}

private struct CardHeaderView: View {
    let card: AnalogCard
    let onDotsChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title)
                        .font(.largeTitle.bold())
                    Text(card.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DotsControl(current: card.dots, accent: card.tab.accent, onChange: onDotsChange)
            }
            Text(card.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DotsControl: View {
    let current: Int
    let accent: Color
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= current ? accent : Color.neutralSurface)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
                    .onTapGesture { onChange(index) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondaryGroupedBackground))
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let tab: CardTab
    let focusMode: Bool
    let onToggle: () -> Void
    let onSetSignal: (TaskSignal) -> Void
    let onMove: (CardTab) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.signal.icon)
                    .foregroundStyle(task.signal.color)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(task.text)
                    .font(focusMode ? .title3.weight(.semibold) : .body)
                    .strikethrough(task.signal == .done)
                Text(task.signal.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Section("Set signal") {
                    ForEach(TaskSignal.allCases) { signal in
                        Button {
                            onSetSignal(signal)
                        } label: {
                            Label(signal.label, systemImage: signal.icon)
                                .foregroundStyle(signal.color)
                        }
                    }
                }

                Section("Move to") {
                    ForEach(CardTab.allCases.filter { $0 != tab }) { destination in
                        Button(destination.title) {
                            onMove(destination)
                        }
                    }
                }

                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondaryGroupedBackground)
        )
        .onDrag {
            let raw = "\(task.id.uuidString)|\(tab.rawValue)"
            return NSItemProvider(object: raw as NSString)
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggle()
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if tab != .today {
                Button {
                    onMove(.today)
                } label: {
                    Label("Today", systemImage: "sun.max")
                }
                .tint(.orange)
            }
            if tab != .next {
                Button {
                    onMove(.next)
                } label: {
                    Label("Next", systemImage: "forward.end")
                }
                .tint(.blue)
            }
            if tab != .someday {
                Button {
                    onMove(.someday)
                } label: {
                    Label("Someday", systemImage: "moon.zzz")
                }
                .tint(.purple)
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ContentView()
}

private extension Color {
    static var groupedBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.gray)
        #endif
    }

    static var secondaryGroupedBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.lightGray)
        #endif
    }

    static var neutralSurface: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray5)
        #elseif canImport(AppKit)
        return Color(NSColor.systemGray)
        #else
        return Color(.gray)
        #endif
    }
}
