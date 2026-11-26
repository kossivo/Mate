import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

public struct DocumentScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recognizedText: String = ""
    @State private var detectedName: String = ""
    @State private var detectedPhone: String = ""
    @State private var detectedEmail: String = ""
    @State private var parsedItems: [ParsedCaptureItem] = []
    @State private var showingCameraScanner: Bool = false
    @State private var cameraUnavailableAlert: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessingOCR: Bool = false

    private let parser = DeterministicCaptureParser()
    public let onAddContactOrTask: (TaskItem) -> Void
    public let onAddEvent: ((TimeBlock) -> Void)?

    public init(
        onAddContactOrTask: @escaping (TaskItem) -> Void,
        onAddEvent: ((TimeBlock) -> Void)? = nil
    ) {
        self.onAddContactOrTask = onAddContactOrTask
        self.onAddEvent = onAddEvent
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.viewfinder.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(MateTheme.opticWhite)
                        Text("Scan Schedule & Cards")
                            .font(.title2.bold())
                            .foregroundStyle(MateTheme.opticWhite)
                        Text("Scan notes, meeting agendas, or business cards.")
                            .font(.subheadline)
                            .foregroundStyle(MateTheme.silverMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // Action triggers: Camera & Photo Library
                    HStack(spacing: 12) {
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
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                Text("Take Photo")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.opticWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                            )
                        }

                        #if canImport(PhotosUI)
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Choose from Library")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.opticWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                            )
                        }
                        #endif
                    }
                    .padding(.horizontal)

                    if isProcessingOCR {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(MateTheme.opticWhite)
                            Text("Reading text from document...")
                                .font(.caption.bold())
                                .foregroundStyle(MateTheme.silverMuted)
                        }
                        .padding(.vertical, 6)
                    }

                    // Text Editor / Paste
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXTRACTED TEXT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(MateTheme.silverMuted)

                        TextField("Paste schedule, notes, or scanned content here...", text: $recognizedText, axis: .vertical)
                            .lineLimit(4...7)
                            .padding()
                            .background(MateTheme.cardBackground)
                            .foregroundStyle(MateTheme.opticWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                            )
                            .onChange(of: recognizedText) { _, newText in
                                analyzeScannedText(newText)
                            }
                    }
                    .padding(.horizontal)

                    // Extracted Schedule items
                    if !parsedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RECOGNIZED SCHEDULE & TASKS (\(parsedItems.count))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(MateTheme.silverMuted)

                            ForEach(parsedItems.indices, id: \.self) { idx in
                                let item = parsedItems[idx]
                                HStack {
                                    Image(systemName: item.itemType == .event ? "calendar" : "bell.fill")
                                        .foregroundStyle(item.itemType == .event ? Color.indigo : Color.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(MateTheme.opticWhite)
                                        if let d = item.deadline {
                                            Text(d.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(MateTheme.silverMuted)
                                        }
                                    }
                                    Spacer()
                                    Text(item.itemType == .event ? "Event" : "Task")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(MateTheme.elevatedCard)
                                        .foregroundStyle(MateTheme.silverMuted)
                                        .clipShape(Capsule())
                                }
                                .padding(12)
                                .background(MateTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke(MateTheme.microBorder, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Extracted Contact info
                    if !detectedPhone.isEmpty || !detectedEmail.isEmpty || !detectedName.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONTACT INFORMATION")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(MateTheme.silverMuted)

                            VStack(alignment: .leading, spacing: 6) {
                                if !detectedName.isEmpty {
                                    Label("Name: \(detectedName)", systemImage: "person.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(MateTheme.opticWhite)
                                }
                                if !detectedPhone.isEmpty {
                                    Label("Phone: \(detectedPhone)", systemImage: "phone.fill")
                                        .font(.caption)
                                        .foregroundStyle(MateTheme.silverMuted)
                                }
                                if !detectedEmail.isEmpty {
                                    Label("Email: \(detectedEmail)", systemImage: "envelope.fill")
                                        .font(.caption)
                                        .foregroundStyle(MateTheme.silverMuted)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MateTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(MateTheme.microBorder, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Save Button
                    Button {
                        // 1. If parsed schedule items found, save all
                        if !parsedItems.isEmpty {
                            for item in parsedItems {
                                if item.itemType == .event, let onAddEvent {
                                    let start = item.deadline ?? Date()
                                    let end = start.addingTimeInterval(item.estimatedDuration)
                                    let block = TimeBlock(
                                        title: item.title,
                                        startTime: start,
                                        endTime: end,
                                        isLocked: true,
                                        category: item.category ?? "Scanned Schedule"
                                    )
                                    onAddEvent(block)
                                } else {
                                    let task = TaskItem(
                                        title: item.title,
                                        category: item.category ?? "Scanned",
                                        deadline: item.deadline,
                                        estimatedDuration: item.estimatedDuration,
                                        priority: item.priority,
                                        status: .planned
                                    )
                                    onAddContactOrTask(task)
                                }
                            }
                        }

                        // 2. If contact info found, save contact follow-up
                        if !detectedName.isEmpty || !detectedPhone.isEmpty || !detectedEmail.isEmpty {
                            let title = detectedName.isEmpty ? "Follow up on scanned note" : "Connect with \(detectedName)"
                            let notes = "Phone: \(detectedPhone) | Email: \(detectedEmail)\n\nOriginal text:\n\(recognizedText)"
                            let task = TaskItem(
                                title: title,
                                notes: notes,
                                category: "Contacts & Networking",
                                priority: .high,
                                status: .inbox
                            )
                            onAddContactOrTask(task)
                        } else if parsedItems.isEmpty {
                            // Generic note
                            let task = TaskItem(
                                title: recognizedText.components(separatedBy: .newlines).first ?? "Scanned Note",
                                notes: recognizedText,
                                category: "Notes",
                                priority: .medium,
                                status: .inbox
                            )
                            onAddContactOrTask(task)
                        }

                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                            Text("Save to Schedule & Notes")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(recognizedText.isEmpty ? MateTheme.elevatedCard : MateTheme.opticWhite)
                        .foregroundStyle(recognizedText.isEmpty ? MateTheme.slateDim : MateTheme.pureBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(recognizedText.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Scan Schedule & Cards")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(MateTheme.opticWhite)
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
            #if canImport(PhotosUI)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    isProcessingOCR = true
                    #if canImport(UIKit)
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        performOCR(on: uiImage)
                    }
                    #endif
                    isProcessingOCR = false
                }
            }
            #endif
            .onAppear {
                if !recognizedText.isEmpty {
                    analyzeScannedText(recognizedText)
                }
            }
            .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Camera is available on a physical iPhone. In simulator, choose an image from Photos or paste text directly.")
            }
        }
    }

    #if canImport(UIKit) && canImport(Vision)
    private func performOCR(on image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        var lines: [String] = []

        let request = VNRecognizeTextRequest { req, err in
            guard err == nil, let observations = req.results as? [VNRecognizedTextObservation] else { return }
            for obs in observations {
                if let top = obs.topCandidates(1).first {
                    lines.append(top.string)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        let full = lines.joined(separator: "\n")
        Task { @MainActor in
            self.recognizedText = full
            self.analyzeScannedText(full)
        }
    }
    #endif

    private func analyzeScannedText(_ text: String) {
        // 1. Phone extraction
        let phoneRegex = "(?:\\+?\\d{1,3}[- ]?)?\\b0?\\d{9,10}\\b"
        if let match = text.range(of: phoneRegex, options: .regularExpression) {
            detectedPhone = String(text[match])
        }

        // 2. Email extraction
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        if let match = text.range(of: emailRegex, options: .regularExpression) {
            detectedEmail = String(text[match])
        }

        // 3. Name extraction
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let first = lines.first, !first.contains("@") && !first.contains("0") && first.count < 40 {
            detectedName = first
        }

        // 4. Natural language schedule and task parsing
        parsedItems = parser.parse(text: text)
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
