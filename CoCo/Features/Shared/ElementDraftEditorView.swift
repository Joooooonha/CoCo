import SwiftUI

/// Form sheet for creating or editing a course element draft.
/// Used by the registration flow and by owner element editing in explore.
struct ElementDraftEditorView: View {
    @State private var draft: ElementDraft
    let isNew: Bool
    let onSave: (ElementDraft) -> Void
    let onDelete: (ElementDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        draft: ElementDraft,
        onSave: @escaping (ElementDraft) -> Void,
        onDelete: @escaping (ElementDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.isNew = draft.title.isEmpty && draft.description.isEmpty
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("분류") {
                    Picker("카테고리", selection: $draft.category) {
                        ForEach(ElementCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.symbolName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("내용") {
                    TextField("제목 (예: 전망 좋은 다리)", text: $draft.title)

                    TextField("짧은 설명", text: $draft.description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    LabeledContent("경로상 위치", value: distanceLabel)
                }

                if !isNew {
                    Section {
                        Button("요소 삭제", role: .destructive) {
                            onDelete(draft)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "요소 추가" : "요소 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var distanceLabel: String {
        if draft.distanceFromStartMeters >= 1_000 {
            return String(format: "출발점에서 %.1f km", Double(draft.distanceFromStartMeters) / 1_000)
        }
        return "출발점에서 \(draft.distanceFromStartMeters) m"
    }
}

extension ElementDraft {
    init(element: CourseElement) {
        self.init(
            id: element.id,
            category: element.category,
            latitude: element.latitude,
            longitude: element.longitude,
            distanceFromStartMeters: element.distanceFromStartMeters,
            title: element.title,
            description: element.description
        )
    }
}
