import SwiftUI

/// 聊天页：从岛台位置“放大”进来（zoom 转场）。顶部头像 + 状态，三个照顾按钮常驻在对话上方。
struct ChatView: View {
    @ObservedObject var chat: ChatStore
    @ObservedObject var needs: NeedsStore
    var pose: Pose
    var character: Character
    var onCare: (Need) -> Void
    @ObservedObject var profile: ProfileStore
    var onFeed: (Food) -> Void
    var showClose = true
    @State private var draft = ""
    @State private var showFood = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content.sheet(isPresented: $showFood) { FoodPicker(profile: profile) { onFeed($0) } }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack(spacing: 12) {
                ZStack(alignment: .bottom) {
                    Color.black
                    DressedPetView(pet: character.pet, pose: pose, frame: needs.urgent?.frame ?? "", accessories: character.accessories ?? []).frame(width: 40, height: 40)
                }
                .frame(width: 48, height: 48).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(ChatStore.petName).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
                    if let n = needs.urgent {
                        Text(T("{0} · 等你{1}", n.label, n.careVerb)).font(.system(size: 12)).foregroundStyle(Theme.alert)
                    }
                }
                Spacer()
                if showClose {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                            .frame(width: 44, height: 44).background(Theme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            // 宠物房间：三个照顾按钮
            HStack(spacing: 8) {
                ForEach(Need.allCases, id: \.self) { n in
                    let urgent = needs.level(n) < Need.threshold
                    Button { if n == .hungry { showFood = true } else { onCare(n) } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: n.careSymbol).font(.system(size: 20))
                                .foregroundStyle(urgent ? Color(hex: "#1A1206") : Theme.needColor(n))
                            Text("\(n.careVerb) · \(Int(needs.level(n) * 100))%")
                                .font(.system(size: 13, weight: urgent ? .bold : .regular))
                                .foregroundStyle(urgent ? Color(hex: "#1A1206") : Theme.text)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(.plain)
                    .background(urgent ? Theme.alert : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(urgent ? .clear : Theme.surface2, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
            Rectangle().fill(Color(hex: "#1F1C27")).frame(height: 1).padding(.horizontal, 16)

            // 消息流
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chat.messages) { m in
                            HStack {
                                if m.role == .me { Spacer(minLength: 60) }
                                VStack(alignment: .leading, spacing: 3) {
                                    if m.role == .bot, let f = m.frame {
                                        DressedPetView(pet: character.pet, pose: pose, frame: f, accessories: character.accessories ?? [])
                                            .frame(width: 96, height: 96)
                                    }
                                    Text(m.text).font(.system(size: 15)).lineSpacing(3)
                                    Text(m.at, style: .time).font(.system(size: 10)).opacity(0.55)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(m.role == .me ? Theme.accent : Theme.surface)
                                .foregroundStyle(m.role == .me ? Color(hex: "#15101F") : Theme.text)
                                .clipShape(UnevenRoundedRectangle(
                                    topLeadingRadius: 18, bottomLeadingRadius: m.role == .me ? 18 : 6,
                                    bottomTrailingRadius: m.role == .me ? 6 : 18, topTrailingRadius: 18))
                                if m.role == .bot { Spacer(minLength: 60) }
                            }
                            .id(m.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: chat.messages.count) { _, _ in
                    if let last = chat.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .onAppear { if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }

            // 输入栏
            HStack(spacing: 8) {
                TextField(T("和它说点什么…"), text: $draft)
                    .font(.system(size: 15)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 16).frame(minHeight: 44)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().stroke(Theme.surface2, lineWidth: 1))
                    .onSubmit(send)
                    .onChange(of: draft) { _, t in typingChanged(!t.isEmpty) }
                    .onDisappear { typingChanged(false) }
                Button(action: send) {
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: "#15101F"))
                        .frame(width: 44, height: 44).background(Theme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        }
        .background(Theme.ground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /// 你在打字 → 岛台上它也敲键盘；停手 2.5 秒算打完
    @State private var typingStop: Task<Void, Never>? = nil
    private func typingChanged(_ on: Bool) {
        typingStop?.cancel()
        NotificationCenter.default.post(name: .userTyping, object: on)
        guard on else { return }
        typingStop = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { NotificationCenter.default.post(name: .userTyping, object: false) }
        }
    }

    private func send() {
        typingChanged(false)
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        draft = ""
        needs.cheer(0.05)                       // 聊天也让它开心
        NotificationCenter.default.post(name: .userChatted, object: nil)
        Task { await chat.send(text, pose: pose) }
    }
}
