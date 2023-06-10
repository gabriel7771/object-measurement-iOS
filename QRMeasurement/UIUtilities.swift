//
//  UIUtilities.swift
//  QRMeasurement
//
//  Created by Juan Bustos on 7/06/23.
//

import AVFoundation
import CoreVideo
import MLKit
import UIKit

public class UIUtilities {
    
    public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
        guard rectangle.isValid() else { return }
        let rectangleView = UIView(frame: rectangle)
        rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
        rectangleView.alpha = Constants.rectangleViewAlpha
        rectangleView.backgroundColor = color
        rectangleView.isAccessibilityElement = true
        rectangleView.accessibilityIdentifier = Constants.rectangleViewIdentifier
        view.addSubview(rectangleView)
    }
}

private enum Constants {
  static let rectangleViewAlpha: CGFloat = 0.3
  static let rectangleViewCornerRadius: CGFloat = 10.0
  static let rectangleViewIdentifier = "MLKit Rectangle View"
}

extension CGRect {
  /// Returns a `Bool` indicating whether the rectangle's values are valid`.
  func isValid() -> Bool {
    return
      !(origin.x.isNaN || origin.y.isNaN || width.isNaN || height.isNaN || width < 0 || height < 0)
  }
}
