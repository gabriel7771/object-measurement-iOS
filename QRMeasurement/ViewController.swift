//
//  ViewController.swift
//  QRMeasurement
//
//  Created by Juan Bustos on 7/06/23.
//

import UIKit
import MLImage
import MLKit

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var takePictureButton: UIButton!
    @IBOutlet var addBoxButton: UIButton!
    
    /// A string holding current results from detection.
    var resultsText = ""
    
    var pixelToCmRatio: CGFloat = 1.0
    
    var buttonsList = [UIButton]()
    
    var units = "px"
    
    /// An overlay view that displays detection annotations.
    private lazy var annotationOverlayView: UIView = {
      precondition(isViewLoaded)
      let annotationOverlayView = UIView(frame: .zero)
      annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
      annotationOverlayView.clipsToBounds = true
      return annotationOverlayView
    }()
        
    override func viewDidLoad() {
        super.viewDidLoad()
                
        takePictureButton.backgroundColor = .systemBlue
        takePictureButton.setTitle("Take Picture", for: .normal)
        takePictureButton.setTitleColor(.white, for: .normal)
        
        addBoxButton.setTitle("Add Box", for: .normal)
        
        imageView.backgroundColor = .systemGray
        imageView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])
    }
    
    @IBAction func didTapButton() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @IBAction func onClickAddBox() {
        let width = 100.0
        let height = 100.0
        let xPos = (self.imageView.frame.width / 2.0) - (width / 2)
        let yPos = (self.imageView.frame.height / 2.0) - (height / 2)
        let button = UIButton(frame: CGRect(x: xPos, y: yPos, width: width, height: height))
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.titleLabel?.font = .systemFont(ofSize: 10)
        button.titleLabel?.numberOfLines = 2
        self.imageView.isUserInteractionEnabled = true
        self.imageView.addSubview(button)
        self.addPanGestureRecognizer(button: button)
        buttonsList.append(button)
    }
    
    func addPanGestureRecognizer(button: UIButton) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        button.addGestureRecognizer(panGesture)
    }
    
    var startX: CGFloat = 0.0
    var startY: CGFloat = 0.0
    var touchX: TouchX = .left
    var touchY: TouchY = .top
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let view = gesture.view!
        let translation = gesture.translation(in: view.superview)
        let location = gesture.location(in: view.superview)
        if gesture.state == .began {
            startX = location.x
            startY = location.y
            let centerX = view.frame.midX
            let centerY = view.frame.midY
            if startX > centerX {
                touchX = .right
            } else {
                touchX = .left
            }
            if startY > centerY {
                touchY = .bottom
            } else {
                touchY = .top
            }
        } else {
            let endX = location.x
            let endY = location.y
            let deltaDx = endX - startX
            let deltaDy = endY - startY
            var tx = view.frame.minX
            var ty = view.frame.minY
            var width = view.frame.width
            var height = view.frame.height
            if touchX == .left {
                width -= deltaDx
                tx += deltaDx
            } else {
                width += deltaDx
            }
            if touchY == .bottom {
                height += deltaDy
            } else {
                height -= deltaDy
                ty += deltaDy
            }
            startX = endX
            startY = endY
            let rect = CGRect(x: tx, y: ty, width: width, height: height)
            view.frame = rect
            if let button = view as? UIButton {
                self.recalculateDimensions(button: button)
            }
        }
    }

    func recalculateDimensions(button: UIButton) {
        let widthCm = button.frame.width / pixelToCmRatio
        let heightCm = button.frame.height / pixelToCmRatio
        let displayWidth = String(format: "%.2f", widthCm)
        let displayHeight = String(format: "%.2f", heightCm)
        let displayText = "\(displayWidth) \(units) \n \(displayHeight) \(units)"
        button.setTitle(displayText, for: UIControl.State.normal)
    }
    
    func detectBarcodes(image: UIImage) {
        let format = BarcodeFormat.all
        let barcodeOptions = BarcodeScannerOptions(formats: format)
        
        let barcodeScanner = BarcodeScanner.barcodeScanner(options: barcodeOptions)
        
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        
        weak var weakSelf = self
        barcodeScanner.process(visionImage) { features, error in
            guard let strongSelf = weakSelf else {
                return
            }
            
            guard error == nil, let features = features, !features.isEmpty else {
                let errorString = error?.localizedDescription ?? "No results found"
                strongSelf.resultsText = "On-Device barcode detection failed with error: \(errorString)"
                strongSelf.showResults()
                NSLog("!! Barcode detection failed with error: \(errorString)")
                return
            }
            
            features.forEach { feature in
                let transformedRect = feature.frame.applying(strongSelf.transformMatrix())
                self.calculatePixelToCmRatio(rect: transformedRect, barcode: feature)
                UIUtilities.addRectangle(
                  transformedRect,
                  to: strongSelf.annotationOverlayView,
                  color: UIColor.green
                )
            }
            
            strongSelf.resultsText = features.map { feature in
                return "DisplayValue: \(feature.displayValue ?? ""), RawValue: "
                  + "\(feature.rawValue ?? ""), Frame: \(feature.frame)"
            }.joined(separator: "\n")
            strongSelf.showResults()
        }
    }
    
    func calculatePixelToCmRatio(rect: CGRect, barcode: Barcode) {
        let widthPx = rect.width
        NSLog("!!widthPx: \(widthPx)")
        guard let qrPayload = extractQRPayload(barcode: barcode) else {
            return
        }
        let qrPerimeterPx = 4 * widthPx
        let qrWidthCm = qrPayload.width
        let qrPerimeterCm = 4 * qrWidthCm
        self.pixelToCmRatio = qrPerimeterPx / qrPerimeterCm
        NSLog("!! 1cm is equal to \(self.pixelToCmRatio) pixels")
    }
    
    func extractQRPayload(barcode: Barcode) -> QRPayload? {
        let value = barcode.displayValue
        guard let payload = value?.toJSON() as? [String: AnyObject] else {
            return nil
        }
        guard let width = payload["width"] as? CGFloat else {
            return nil
        }
        guard let height = payload["height"] as? CGFloat else {
            return nil
        }
        guard let units = payload["units"] as? String else {
            return nil
        }
        self.units = units
        return QRPayload(width: width, height: height, units: units)
    }
    
    private func updateImageView(with image: UIImage) {
        let qualityMultiplier: CGFloat = 2
        let orientation = UIApplication.shared.statusBarOrientation
        var scaledImageWidth: CGFloat = 0.0
        var scaledImageHeight: CGFloat = 0.0
        switch orientation {
        case .portrait, .portraitUpsideDown, .unknown:
          scaledImageWidth = imageView.bounds.size.width
          scaledImageHeight = image.size.height * scaledImageWidth / image.size.width
        case .landscapeLeft, .landscapeRight:
          scaledImageWidth = image.size.width * scaledImageHeight / image.size.height
          scaledImageHeight = imageView.bounds.size.height
        @unknown default:
          fatalError()
        }
        weak var weakSelf = self
        DispatchQueue.global(qos: .userInitiated).async {
          // Scale image while maintaining aspect ratio so it displays better in the UIImageView.
          var scaledImage = image.scaledImage(
            with: CGSize(width: scaledImageWidth * qualityMultiplier, height: scaledImageHeight * qualityMultiplier)
          )
          scaledImage = scaledImage ?? image
          guard let finalImage = scaledImage else { return }
          DispatchQueue.main.async {
            weakSelf?.imageView.image = finalImage
            self.detectBarcodes(image: finalImage)
          }
        }
    }
    
    private func transformMatrix() -> CGAffineTransform {
        guard let image = imageView.image else { return CGAffineTransform() }
        let imageViewWidth = imageView.frame.size.width
        let imageViewHeight = imageView.frame.size.height
        let imageWidth = image.size.width
        let imageHeight = image.size.height

        let imageViewAspectRatio = imageViewWidth / imageViewHeight
        let imageAspectRatio = imageWidth / imageHeight
        let scale =
          (imageViewAspectRatio > imageAspectRatio)
          ? imageViewHeight / imageHeight : imageViewWidth / imageWidth

        // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
        // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
        let scaledImageWidth = imageWidth * scale
        let scaledImageHeight = imageHeight * scale
        let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
        let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

        var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }
    
    private func showResults() {
        let resultsAlertController = UIAlertController(
          title: "Detection Results",
          message: nil,
          preferredStyle: .actionSheet
        )
        resultsAlertController.addAction(
          UIAlertAction(title: "OK", style: .destructive) { _ in
            resultsAlertController.dismiss(animated: true, completion: nil)
          }
        )
        resultsAlertController.message = resultsText
        resultsAlertController.popoverPresentationController?.sourceView = self.view
        present(resultsAlertController, animated: true, completion: nil)
        print(resultsText)
      }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true)
        
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            return
        }
        updateImageView(with: image)
    }
}

extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}

public class QRPayload {
    public var width: CGFloat
    public var height: CGFloat
    public var units: String
    
    init(width: CGFloat, height: CGFloat, units: String) {
        self.width = width
        self.height = height
        self.units = units
    }
}

enum TouchX {
    case left
    case right
}

enum TouchY {
    case top
    case bottom
}
