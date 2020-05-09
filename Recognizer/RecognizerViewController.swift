//
//  RecognizerViewController.swift
//  Recognizer
//
//  Created by Влад Купряков on 22.03.2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

protocol IRecognizerViewController: AnyObject {
    var bufferSize: CGSize { get }
    var isObjectDetectionLayersCleaned: Bool { get set }
    var isImageClassificationLayersCleaned: Bool { get set }
    
    func drawImageClassificationResult(image: CGImage?, text: NSAttributedString)
    func drawObjectDetectionResult(objectsInfo: [(bounds: CGRect, identifier: String, confidence: Float)])
    func cleanImageClassificationLayers()
    func cleanObjectDetectionLayers()
    func setupTextOnModelTypeButton(text: String)
}

final class RecognizerViewController: ViewController, IRecognizerViewController {
    
    // Dependencies
    let presenter = RecognizerPresenter()
    
    // Layers
    private var detectionOverlay = CALayer()
    private let textLayer = CATextLayer()
    private let imageLayer = CALayer()
    private var button = UIButton()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.view = self
        presenter.viewDidLoad()
        setupButton()
    }
    
    // MARK: IRecognizerViewController
    
    var isObjectDetectionLayersCleaned = false
    var isImageClassificationLayersCleaned = false
    
    func drawImageClassificationResult(image: CGImage?, text: NSAttributedString) {
        textLayer.string = text
        imageLayer.contents = image
    }
    
    func drawObjectDetectionResult(objectsInfo: [(bounds: CGRect, identifier: String, confidence: Float)]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil
        for object in objectsInfo {
            let shapeLayer = createRoundedRectLayerWithBounds(object.bounds)
            let textLayer = createTextSubLayerInBounds(object.bounds,
                                                       identifier: object.identifier,
                                                       confidence: object.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
        updateLayerGeometry()
        CATransaction.commit()
    }
    
    func cleanImageClassificationLayers() {
        guard !isImageClassificationLayersCleaned else { return }
        isImageClassificationLayersCleaned = true
        textLayer.string = ""
        imageLayer.contents = nil
    }
    
    func cleanObjectDetectionLayers() {
        guard !isObjectDetectionLayersCleaned else { return }
        isObjectDetectionLayersCleaned = true
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil
        CATransaction.commit()
    }
    
    func setupTextOnModelTypeButton(text: String) {
        button.setTitle(text, for: .normal)
    }
    
    override func setupAVCapture() {
        super.setupAVCapture()
        
        startCaptureSession()
        setupLayers()
        setupTextLayer()
        setupImageLayer()
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        presenter.videoDidCaptured(pixelBuffer)
    }
    
    // MARK: Private
    
    private func setupTextLayer() {
        textLayer.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        textLayer.position = CGPoint(x: self.view.center.x - 20, y: self.view.center.y + 220)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        rootLayer.addSublayer(textLayer)
    }
    
    private func setupImageLayer() {
        imageLayer.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        imageLayer.position = CGPoint(x: self.view.center.x + 170, y: self.view.center.y + 220)
        rootLayer.addSublayer(imageLayer)
    }
    
    func setupLayers() {
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    private func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint (x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    private func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    private func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
//        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.borderWidth = 2
        if #available(iOS 13.0, *) {
            shapeLayer.borderColor = CGColor(srgbRed: 0, green: 0.5, blue: 0.5, alpha: 0.8)
        } else {
            // Fallback on earlier versions
        }
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    @objc private func didTapChangeModelTypeButton() {
        presenter.didTapChangeModelTypeButton()
    }
    
    private func setupButton() {
                button.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        //        button.frame = CGRect(x: view.center.x - 25, y: view.center.y - 25, width: 50, height: 50)
                button.addTarget(self, action: #selector(didTapChangeModelTypeButton), for: .touchUpInside)
                view.addSubview(button)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.layer.cornerRadius = 12
                button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
                button.widthAnchor.constraint(equalToConstant: 200).isActive = true
                button.heightAnchor.constraint(equalToConstant: 50).isActive = true
                button.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -30).isActive = true
            
                rootLayer.addSublayer(button.layer)
    }
}
