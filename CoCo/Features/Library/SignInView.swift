import SwiftUI

/// The gate every session starts at.
///
/// Signing in is required rather than optional because an account has to
/// outlive the device that made it. Identity lives with Naver or Kakao, so the
/// same login on a new phone reaches the same courses and scraps.
struct SignInView: View {
    @State private var store = AccountStore()
    let onSignedIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("CoCo")
                    .font(.largeTitle.weight(.bold))

                Text("다른 러너의 코스를 경로와 맥락 정보로\n미리 확인하고 달릴 곳을 고르세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: 12) {
                ForEach(AuthProvider.allCases, id: \.self) { provider in
                    Button {
                        Task { await signIn(with: provider) }
                    } label: {
                        HStack {
                            Spacer()
                            Text("\(provider.displayName)로 계속하기")
                                .font(.headline)
                            Spacer()
                        }
                        .frame(minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(provider.brandTint)
                    .foregroundStyle(provider.brandForeground)
                    .disabled(store.isBusy)
                    .accessibilityHint("\(provider.displayName) 계정으로 로그인합니다")
                }

                if store.isBusy {
                    ProgressView()
                        .padding(.top, 4)
                }

                Text("로그인하면 기기를 바꿔도 코스와 스크랩이 그대로 이어져요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .alert(
            "로그인하지 못했어요",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            )
        ) {
            Button("확인", role: .cancel) { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func signIn(with provider: AuthProvider) async {
        await store.signIn(with: provider)
        if store.isSignedIn {
            onSignedIn()
        }
    }
}

extension AuthProvider {
    /// Each provider's own colour, so the button looks like the service it
    /// opens rather than a generic one.
    var brandTint: Color {
        switch self {
        case .naver: Color(red: 0.012, green: 0.784, blue: 0.235)
        case .kakao: Color(red: 0.996, green: 0.898, blue: 0.0)
        }
    }

    var brandForeground: Color {
        switch self {
        case .naver: .white
        case .kakao: .black
        }
    }
}
