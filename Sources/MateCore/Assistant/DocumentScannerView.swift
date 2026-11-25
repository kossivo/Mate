import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif

public struct ScannedCardResult: Sendable, Equatable {
    public var rawText: String
    public var extractedName: String?
    public var extractedPhone: String?
    public var extractedEmail: String?

    public init(rawText: String, extractedName: String? = nil, extractedPhone: String? = nil, extractedEmail: String? = nil) {
        self.rawText = rawText
        self.extractedName = extractedName
        self.extractedPhone = extractedPhone
        self.extractedEmail = extractedEmail
    }
}

public struct DocumentScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recognizedText: String = ""
    @State private var detectedName: String = ""
    @State private var detectedPhone: String = ""
    @State private var detectedEmail: String = ""
    public let onAddContactOrTask: (TaskItem) -> Void

    public init(onAddContactOrTask: @escaping (TaskItem) -> Void) {
        self.onAddContactOrTask = onAddContactOrTask
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("Card & Document Scanner")
                        .font(.title2.bold())
                    Text("Scan a business card, sticky note, or invoice to extract action items and contact details instantly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Card Text / Paste Input")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    TextField("e.g. Tuấn Nguyễn - Tech Lead\nPhone: 0901234567\nEmail: tuan@tech.vn", text: $recognizedText, axis: .vertical)
                        .lineLimit(4...8)
                        .padding()
                        .background(MateTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: recognizedText) { _, newText in
                            analyzeScannedText(newText)
                        }
                }
                .padding(.horizontal)

                if !detectedPhone.isEmpty || !detectedEmail.isEmpty || !detectedName.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Extracted Entities")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        if !detectedName.isEmpty {
                            Label("Name: \(detectedName)", systemImage: "person.fill")
                                .font(.subheadline)
                        }
                        if !detectedPhone.isEmpty {
                            Label("Phone: \(detectedPhone)", systemImage: "phone.fill")
                                .font(.subheadline)
                        }
                        if !detectedEmail.isEmpty {
                            Label("Email: \(detectedEmail)", systemImage: "envelope.fill")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Spacer()

                Button {
                    let title = detectedName.isEmpty ? "Follow up on scanned note" : "Connect with \(detectedName)"
                    let notes = "Phone: \(detectedPhone) | Email: \(detectedEmail)\n\nOriginal Text:\n\(recognizedText)"
                    let task = TaskItem(
                        title: title,
                        notes: notes,
                        category: "Contacts & Networking",
                        priority: .high,
                        status: .inbox
                    )
                    onAddContactOrTask(task)
                    dismiss()
                } label: {
                    Text("Save Contact Follow-Up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(recognizedText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(recognizedText.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Scanner")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func analyzeScannedText(_ text: String) {
        // Extract phone number (VN / International)
        let phoneRegex = "(?:\\+?\\d{1,3}[- ]?)?\\b0?\\d{9,10}\\b"
        if let match = text.range(of: phoneRegex, options: .regularExpression) {
            detectedPhone = String(text[match])
        }

        // Extract email
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        if let match = text.range(of: emailRegex, options: .regularExpression) {
            detectedEmail = String(text[match])
        }

        // First non-empty line as name guess
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let first = lines.first, !first.contains("@") && !first.contains("0") {
            detectedName = first
        }
    }
}
