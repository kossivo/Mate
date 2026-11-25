import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif
#if canImport(Vision)
import Vision
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
    @State private var showingCameraScanner: Bool = false
    @State private var cameraUnavailableAlert: Bool = false
    public let onAddContactOrTask: (TaskItem) -> Void

    public init(onAddContactOrTask: @escaping (TaskItem) -> Void) {
        self.onAddContactOrTask = onAddContactOrTask
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        Text("Card & Document Scanner")
                            .font(.title2.bold())
                        Text("Point your camera at a business card, schedule note, or agenda to extract items instantly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Native Camera Trigger Button
                    Button {
                        #if os(iOS)
                        if VNDocumentCameraViewController.isSupported {
                            showingCameraScanner = true
                        } else {
                            cameraUnavailableAlert = true
                        }
                        #else
                        cameraUnavailableAlert = true
                        #endif
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Open Camera Scanner")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or Paste / Edit Extracted Text")
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
                        Text("Save Action Item & Contact")
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
            .sheet(isPresented: $showingCameraScanner) {
                #if os(iOS)
                DocumentCameraRepresentable { scannedText in
                    recognizedText = scannedText
                    analyzeScannedText(scannedText)
                } onCancel: {
                    showingCameraScanner = false
                }
                #else
                EmptyView()
                #endif
            }
            .alert("Camera Scanner", isPresented: $cameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Camera scanner is supported on physical iOS devices with camera hardware. On simulator, you can paste or edit text directly.")
            }
        }
    }

    private func analyzeScannedText(_ text: String) {
        let phoneRegex = "(?:\\+?\\d{1,3}[- ]?)?\\b0?\\d{9,10}\\b"
        if let match = text.range(of: phoneRegex, options: .regularExpression) {
            detectedPhone = String(text[match])
        }

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        if let match = text.range(of: emailRegex, options: .regularExpression) {
            detectedEmail = String(text[match])
        }

        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let first = lines.first, !first.contains("@") && !first.contains("0") {
            detectedName = first
        }
    }
}

#if os(iOS)
public struct DocumentCameraRepresentable: UIViewControllerRepresentable {
    public let onScanCompleted: (String) -> Void
    public let onCancel: () -> Void

    public init(onScanCompleted: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onScanCompleted = onScanCompleted
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onScanCompleted: onScanCompleted, onCancel: onCancel)
    }

    public final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScanCompleted: (String) -> Void
        private let onCancel: () -> Void

        public init(onScanCompleted: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScanCompleted = onScanCompleted
            self.onCancel = onCancel
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true)
            var extractedLines: [String] = []

            #if canImport(Vision)
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for observation in observations {
                    if let top = observation.topCandidates(1).first {
                        extractedLines.append(top.string)
                    }
                }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["vi-VN", "en-US"]

            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                guard let cgImage = image.cgImage else { continue }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }
            #endif

            let fullText = extractedLines.joined(separator: "\n")
            onScanCompleted(fullText)
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onCancel()
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            onCancel()
        }
    }
}
#endif
