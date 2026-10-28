import SwiftUI

/// 首页的时间线条：一排点，当前项高亮，可横向滚动
struct TimelineStrip: View {
    var steps: Int = 0
    var items: [RoutineItem]
    var current: RoutineItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(steps > 0 ? T("今天 · {0} 步", steps.formatted()) : T("今天")).font(.system(size: 13)).foregroundStyle(Theme.text2)
                Spacer()
                if let c = current { Text(T("现在 · {0}", c.title)).font(.system(size: 13)).foregroundStyle(Theme.accent) }
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(items) { it in
                            let on = it == current
                            VStack(spacing: 6) {
                                Text(it.timeText).font(.system(size: 11)).monospacedDigit().foregroundStyle(on ? Theme.text : Theme.text3)
                                ZStack {
                                    Rectangle().fill(Theme.surface2).frame(height: 2)
                                    Circle().fill(on ? Theme.accent : Theme.surface2).frame(width: on ? 14 : 8, height: on ? 14 : 8)
                                }
                                Image(systemName: it.symbol).font(.system(size: 13)).foregroundStyle(on ? Theme.accent : Theme.text3)
                                Text(it.title).font(.system(size: 11)).foregroundStyle(on ? Theme.text : Theme.text3)
                            }
                            .frame(width: 64)
                            .id(it.id)
                        }
                    }
                }
                .onAppear { if let c = current { proxy.scrollTo(c.id, anchor: .center) } }
                .onChange(of: current) { _, c in if let c { withAnimation { proxy.scrollTo(c.id, anchor: .center) } } }
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// 作息编辑：默认只有起床/睡觉，右上角 + 自己加；左滑删除，点时间改
struct RoutineEditor: View {
    @ObservedObject var routine: RoutineStore
    @State private var adding = false

    var body: some View {
        List {
            Section {
                ForEach($routine.routine.items.sorted(by: { $0.wrappedValue.minutesOfDay < $1.wrappedValue.minutesOfDay })) { $it in
                    HStack(spacing: 12) {
                        Image(systemName: it.symbol).frame(width: 24).foregroundStyle(Theme.accent)
                        TextField(T("名称"), text: $it.title)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { Calendar.current.date(from: DateComponents(hour: it.hour, minute: it.minute)) ?? Date() },
                            set: { d in it.hour = Calendar.current.component(.hour, from: d); it.minute = Calendar.current.component(.minute, from: d) }),
                            displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }
                }
                .onDelete { idx in
                    let sorted = routine.routine.sorted
                    let ids = idx.map { sorted[$0].id }
                    routine.routine.items.removeAll { ids.contains($0.id) }
                }
                Button { adding = true } label: { Label(T("添加一项"), systemImage: "plus.circle.fill") }
            } footer: {
                Text(T("到点它会换成对应的动作，持续 1 小时（睡觉持续到下一项）。左滑删除。"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle(T("每天的安排"))
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $adding) { AddRoutineItem(routine: routine) }
    }
}

/// 添加一项：选一个类型 + 选时间
struct AddRoutineItem: View {
    @ObservedObject var routine: RoutineStore
    @Environment(\.dismiss) private var dismiss
    @State private var pick = 0
    @State private var time = Calendar.current.date(bySetting: .minute, value: 0, of: Date().addingTimeInterval(3600)) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section(T("做什么")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                        ForEach(Routine.presets.indices, id: \.self) { i in
                            let p = Routine.presets[i]
                            Button { pick = i } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: p.symbol).font(.system(size: 18))
                                    Text(p.title).font(.system(size: 12))
                                }
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(pick == i ? Theme.accent.opacity(0.25) : Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(pick == i ? Theme.accent : Theme.text)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section(T("几点")) {
                    DatePicker(T("时间"), selection: $time, displayedComponents: .hourAndMinute)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle(T("添加安排")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("取消")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("添加")) {
                        let p = Routine.presets[pick]
                        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                        routine.routine.items.append(RoutineItem(hour: c.hour ?? 12, minute: c.minute ?? 0, title: p.title, symbol: p.symbol, pose: p.pose, line: p.line))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}
