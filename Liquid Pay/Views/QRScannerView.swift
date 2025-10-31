import SwiftUI
import AVFoundation
import Combine
import PhotosUI
import CoreImage

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRScanner()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    var onCodeScanned: (String) -> Void
    var onManualPay: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            QRScannerRepresentable(scanner: scanner) { code in
                onCodeScanned(code)
                dismiss()
            }
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Gallery upload button
                Button {
                    showImagePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                        Text("Upload from Gallery")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                }
                .padding(.bottom, 12)

                // Manual UPI entry below gallery button
                Button {
                    let action = onManualPay
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { action?() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 18))
                        Text("Pay by UPI ID")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(12)
                }
                .padding(.bottom, 48)
            }
            
            // Scanning frame overlay
            Rectangle()
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 250, height: 250)
                .overlay(
                    VStack {
                        HStack {
                            Rectangle().fill(Color.green).frame(width: 20, height: 3)
                            Spacer()
                            Rectangle().fill(Color.green).frame(width: 20, height: 3)
                        }
                        Spacer()
                        HStack {
                            Rectangle().fill(Color.green).frame(width: 20, height: 3)
                            Spacer()
                            Rectangle().fill(Color.green).frame(width: 20, height: 3)
                        }
                    }
                    .frame(width: 250, height: 250)
                )
        }
        .sheet(isPresented: $showImagePicker) {
            QRImagePicker(selectedImage: $selectedImage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedImage) { oldValue, newImage in
            if let image = newImage {
                detectQRCode(in: image)
            }
        }
    }
    
    private func detectQRCode(in image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            errorMessage = "Failed to process image"
            showError = true
            return
        }
        
        let context = CIContext()
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] else {
            errorMessage = "No QR code found in the image"
            showError = true
            return
        }
        
        if let firstFeature = features.first, let qrString = firstFeature.messageString {
            onCodeScanned(qrString)
            dismiss()
        } else {
            errorMessage = "No QR code found in the image"
            showError = true
        }
    }
}

// MARK: - QR Image Picker
private struct QRImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: QRImagePicker
        
        init(_ parent: QRImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - QR Scanner Logic
class QRScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession?.canAddInput(videoInput) == true {
            captureSession?.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession?.canAddOutput(metadataOutput) == true {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Prevent multiple scans
        guard scannedCode == nil else { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            scannedCode = stringValue
            stopScanning() // Stop scanning after successful scan
        }
    }
}

// MARK: - UIKit Bridge
struct QRScannerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var scanner: QRScanner
    var onCodeScanned: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scanner: scanner)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        guard let captureSession = scanner.captureSession else {
            return viewController
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = UIScreen.main.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        scanner.previewLayer = previewLayer
        
        scanner.startScanning()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let code = scanner.scannedCode {
            scanner.stopScanning()
            onCodeScanned(code)
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        // Cleanup: stop scanning when view is dismissed
        coordinator.scanner.stopScanning()
    }
    
    class Coordinator {
        let scanner: QRScanner
        init(scanner: QRScanner) {
            self.scanner = scanner
        }
    }
}

