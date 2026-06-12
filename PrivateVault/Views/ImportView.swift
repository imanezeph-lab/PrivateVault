import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: VaultViewModel

    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var showDocumentPicker = false
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            List {
                Section("Import From") {
                    PhotosPicker(
                        selection: $photosPickerItems,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: photosPickerItems) { _, items in
                        guard !items.isEmpty else { return }
                        viewModel.handlePickedPhotos(items)
                        dismiss()
                    }

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Files", systemImage: "folder")
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                }
            }
            .navigationTitle("Import Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.image, .video, .gif, .audio, .pdf, .text, .data, .archive, .spreadsheet, .presentation],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    viewModel.handleDocumentPicker(urls: urls)
                case .failure:
                    break
                }
                dismiss()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { url in
                    if let url {
                        viewModel.handleCameraCapture(url: url)
                    }
                    dismiss()
                }
                .ignoresSafeArea()
            }
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (URL?) -> Void
        init(onCapture: @escaping (URL?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let mediaURL = info[.mediaURL] as? URL {
                onCapture(mediaURL)
            } else if let image = info[.originalImage] as? UIImage {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(UUID().uuidString).jpg")
                if let data = image.jpegData(compressionQuality: 0.9) {
                    try? data.write(to: tempURL)
                    onCapture(tempURL)
                } else {
                    onCapture(nil)
                }
            } else {
                onCapture(nil)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            picker.dismiss(animated: true)
        }
    }
}
