import SwiftUI

/// 首页里的聊天：最近几条 + 输入框。点「全部」进完整聊天页。
struct HomeChatCard: View {
    @ObservedObject var chat: ChatStore
    @ObservedObject var needs: NeedsStore
    var pose: Pose
    var character: Character
    var openFull: () -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(T("和它聊聊")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text2)
                Spacer()
                Button(action: openFull) {
                    Text(T("全部 ›")).font(.system(size: 13)).foregroundStyle(Theme.text3)
                }
                .buttonStyle(.press)
            }

            VStack(spacing: 8) {
                let recent = Array(chat.messages.suffix(4))
                if recent.isEmpty {
                    Text(T("还没说过话。随便说一句，它会回你。"))
                        .font(.system(size: 13)).foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                }
                ForEach(recent) { m in
                    HStack(alignment: .bottom, spacing: 8) {
                        if m.role == .me { Spacer(minLength: 50) }
                        if m.role == .bot {
                            ZStack { Color.black; DressedPetView(pet: character.pet, pose: pose, frame: m.frame ?? "", accessories: character.accessories ?? []).frame(width: 26, height: 26) }
                                .frame(width: 30, height: 30).clipShape(Circle())
                        }
                        Text(m.text).font(.system(size: 14)).lineSpacing(2)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(m.role == .me ? Theme.accent : Theme.surface2)
                            .foregroundStyle(m.role == .me ? Color(hex: "#15101F") : Theme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        if m.role == .bot { Spacer(minLength: 50) }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !focused { openFull() } }

            HStack(spacing: 8) {
                TextField(T("和它说点什么…"), text: $draft)
                    .font(.system(size: 15)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).frame(minHeight: 42)
                    .background(Theme.ground, in: Capsule())
                    .overlay(Capsule().stroke(Theme.surface2, lineWidth: 1))
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "#15101F"))
                        .frame(width: 42, height: 42).background(Theme.accent, in: Circle())
                }
                .buttonStyle(.press)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        draft = ""
        needs.cheer(0.05)
        NotificationCenter.default.post(name: .userChatted, object: nil)
        Task { await chat.send(text, pose: pose) }
    }
}
