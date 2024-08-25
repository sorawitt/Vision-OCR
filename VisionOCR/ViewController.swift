//
//  ViewController.swift
//  VisionOCR
//
//  Created by Sorawit Trutsat on 25/8/2567 BE.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var processedImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Unable to access back camera!")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            cameraOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(cameraOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(cameraOutput)
                setupLivePreview()
            }
        } catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }
    
    func setupLivePreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        
        // Add a button to capture the image
        let captureButton = UIButton(frame: CGRect(x: (view.frame.width - 70) / 2, y: view.frame.height - 100, width: 70, height: 70))
        captureButton.layer.cornerRadius = 35
        captureButton.backgroundColor = .red
        captureButton.addTarget(self, action: #selector(didTapCaptureButton), for: .touchUpInside)
        view.addSubview(captureButton)
    }
    
    @objc func didTapCaptureButton() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        if let previewFormatType = settings.availablePreviewPhotoPixelFormatTypes.first {
            settings.previewPhotoFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: previewFormatType
            ]
        }
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            print("Error: fileDataRepresentation is nil")
            return
        }
        
        // Fix the image orientation
        if let correctedImage = image.fixedOrientation() {
            image = correctedImage
        }
        // Perform alignment and then OCR on the captured image
        self.performOCROnImage(image: image)
    }
    
    func performOCROnImage(image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage from UIImage")
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("Unexpected result type from OCR request")
                return
            }
            
            // Draw borders around text containing "Card"
            let borderedImage = self.drawBordersAroundText(in: image, observations: observations)
            
            // Display the processed image
            self.displayProcessedImage(borderedImage)
        }
        
        request.recognitionLanguages = ["th", "en"]
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error)")
        }
    }
    
    func drawBordersAroundText(in image: UIImage, observations: [VNRecognizedTextObservation]) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: .zero)
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        for observation in observations {
            if let topCandidate = observation.topCandidates(1).first {
                let recognizedText = topCandidate.string
                print(recognizedText)
                if recognizedText.hasPrefix("ศาสนา") {
                    let boundingBox = observation.boundingBox
                    let imageSize = image.size
                    
                    // Calculate the bounding box in image coordinates
                    let rect = CGRect(
                        x: boundingBox.origin.x * imageSize.width,
                        y: (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height,
                        width: boundingBox.width * imageSize.width,
                        height: boundingBox.height * imageSize.height
                    )
                    
                    context.fill(rect)
                }
            }
        }
        
        let borderedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return borderedImage
    }

    
    func displayProcessedImage(_ image: UIImage?) {
        guard let image = image else { return }
        
        if processedImageView == nil {
            processedImageView = UIImageView(frame: self.view.bounds)
            processedImageView.contentMode = .scaleAspectFit
            processedImageView.backgroundColor = .black
            self.view.addSubview(processedImageView)
        }
        
        processedImageView.image = image
        processedImageView.isHidden = false
    }
    
}


extension UIImage {
    func fixedOrientation() -> UIImage? {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}
