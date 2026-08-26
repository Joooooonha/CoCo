import SwiftUI

struct ProfileView: View {
    @Bindable var store: AccountStore
    let currentName: String?
    let onRename: (String) async -> Void
    let onSessionReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nameDraft = ""
    @State private var isEditingName = false
    @State private var confirmsSignOut = false
    @State private var confirmsDeletion = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                nameSection

                if store.isSignedIn {
                    signOutSection
                }

                deleteSection
            }
            .navigationTitle("내 계정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .task {
                await store.load()
            }
            .onChange(of: store.sessionDidReset) { _, didReset in
                guard didReset else { return }
                store.acknowledgeSessionReset()
                onSessionReset()
            }
            .alert("이름 바꾸기", isPresented: $isEditingName) {
                TextField("표시 이름 (1~20자)", text: $nameDraft)
                Button("저장") {
                    Task { await onRename(nameDraft) }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("코스와 목록에 표시되는 이름이에요.")
            }
            .alert(
                "문제가 생겼어요",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.clearError() } }
                )
            ) {
                Button("확인", role: .cancel) { store.clearError() }
            } message: {
                Text(store.errorMessage ?? "")
            }
            .confirmationDialog(
                "로그아웃할까요?",
                isPresented: $confirmsSignOut,
                titleVisibility: .visible
            ) {
                Button("로그아웃", role: .destructive) {
                    Task { await store.signOut() }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("다시 로그인하면 코스와 스크랩을 그대로 볼 수 있어요.")
            }
            .confirmationDialog(
                "계정을 삭제할까요?",
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("계정 삭제", role: .destructive) {
                    Task { await store.deleteAccount() }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("내가 만든 코스와 스크랩, 반응이 모두 삭제되고 되돌릴 수 없어요.")
            }
        }
    }

    private var accountSection: some View {
        Section {
            if store.isSignedIn {
                LabeledContent("로그인") {
                    Text(linkedProviderNames)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("로그인하면 기기를 바꾸거나 앱을 다시 설치해도 코스와 스크랩을 그대로 쓸 수 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(AuthProvider.allCases, id: \.self) { provider in
                        Button {
                            Task { await store.signIn(with: provider) }
                        } label: {
                            HStack {
                                Text("\(provider.displayName)로 계속하기")
                                    .font(.headline)
                                Spacer()
                                if store.isBusy {
                                    ProgressView()
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.isBusy)
                        .accessibilityHint("\(provider.displayName) 계정으로 로그인합니다")
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("계정")
        } footer: {
            if !store.isSignedIn {
                Text("지금은 이 기기에서만 쓰는 게스트예요. 앱을 지우면 코스와 스크랩을 되찾을 수 없어요.")
            }
        }
    }

    private var nameSection: some View {
        Section("표시 이름") {
            Button {
                nameDraft = currentName ?? ""
                isEditingName = true
            } label: {
                LabeledContent(currentName ?? "이름 없음") {
                    Text("바꾸기")
                        .foregroundStyle(.tint)
                }
            }
            .buttonStyle(.plain)
            // Without this it reads as the name followed by "바꾸기", which does
            // not say what activating it does.
            .accessibilityLabel("표시 이름 바꾸기")
            .accessibilityValue(currentName ?? "이름 없음")
        }
    }

    private var signOutSection: some View {
        Section {
            Button("로그아웃") {
                confirmsSignOut = true
            }
            .disabled(store.isBusy)
        }
    }

    private var deleteSection: some View {
        Section {
            Button("계정 삭제", role: .destructive) {
                confirmsDeletion = true
            }
            .disabled(store.isBusy)
        } footer: {
            Text("삭제하면 내가 만든 코스와 스크랩, 반응이 모두 사라져요.")
        }
    }

    private var linkedProviderNames: String {
        let providers = store.user?.linkedProviders ?? []
        guard !providers.isEmpty else { return "연결된 계정 없음" }
        return providers.map(\.displayName).joined(separator: ", ")
    }
}

#Preview {
    ProfileView(
        store: AccountStore(),
        currentName: "노을러너",
        onRename: { _ in },
        onSessionReset: {}
    )
}
