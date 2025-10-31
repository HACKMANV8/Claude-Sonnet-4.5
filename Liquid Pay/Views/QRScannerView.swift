import SwiftUI
import AVFoundation
import Combine

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRScanner()
    var onCodeScanned: (String) -> Void
    
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
                
                VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    Text("Scan QR Code")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Text("Position the QR code within the frame")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 80)
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

