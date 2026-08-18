import PhotosUI
import SwiftUI

/// Picks and previews the photo for an element draft.
///
/// Nothing is uploaded here. The draft carries the processed bytes, and the
/// upload happens once the element exists on the server.
struct ElementDraftPhotoPicker: View {
    @Binding var draft: ElementDraft

    @State private var selection: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            photoArea

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selection,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        draft.hasVisiblePhoto ? "사진 바꾸기" : "사진 추가",
                        systemImage: "photo.badge.plus"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .disabled(isProcessing)

                if draft.hasVisiblePhoto {
                    Button("사진 제거", role: .destructive) {
                        removePhoto()
                    }
                    .font(.subheadline)
                    .disabled(isProcessing)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("업로드 전에 사진을 줄이고 촬영 위치 정보를 지워요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .onChange(of: selection) { _, newSelection in
            guard let newSelection else { return }
            Task { await load(newSelection) }
        }
        .task {
            await loadSavedPhotoPreview()
        }
    }

    @ViewBuilder
    private var photoArea: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(height: 140)
            .overlay {
                if isProcessing {
                    ProgressView()
                } else if let preview, draft.hasVisiblePhoto {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("선택한 사진이 없어요")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement()
            .accessibilityLabel(draft.hasVisiblePhoto ? "선택한 요소 사진" : "선택한 사진 없음")
    }

    private func load(_ item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "사진을 불러오지 못했어요. 다시 선택해 주세요."
            return
        }

        do {
            // Processing here rather than at upload time means the preview shows
            // exactly the image that will be sent.
            let processed = try ElementPhotoProcessor().process(data)
            draft.pendingPhoto = processed
            draft.removesSavedPhoto = false
            preview = UIImage(data: processed.data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removePhoto() {
        draft.pendingPhoto = nil
        // The saved photo is only deleted on the server once the draft is
        // saved, so cancelling the sheet leaves it untouched.
        draft.removesSavedPhoto = draft.savedPhoto != nil
        preview = nil
        selection = nil
    }

    private func loadSavedPhotoPreview() async {
        guard preview == nil, draft.pendingPhoto == nil, draft.savedPhoto != nil else { return }
        preview = await ElementPhotoLoader.shared.image(for: draft)
    }
}

extension ElementPhotoLoader {
    /// Draft editing shows the same photo the detail screen does, so it reads
    /// through the same cache.
    func image(for draft: ElementDraft) async -> UIImage? {
        guard let savedPhoto = draft.savedPhoto, !draft.removesSavedPhoto else { return nil }
        return await image(
            cacheKey: ElementPhotoIdentity.cacheKey(elementID: draft.id, uploadedAt: savedPhoto.uploadedAt),
            url: savedPhoto.url
        )
    }
}
