//
//  RecognizerPresenter.swift
//  Recognizer
//
//  Created by Влад Купряков on 22.03.2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import Vision
import UIKit
import AVFoundation

enum ModelType {
    case objectDetector
    case imageClassification
    
    var buttonText: String {
        switch self {
        case .objectDetector: return "Распознавать машины"
        case .imageClassification: return "Распознавать людей"
        }
    }
}

enum Result {
    
    case captain
    case iron
    case spider
    case thor
    case mercedes
    case audi
    case bmw
    
    var string: String {
        switch self {
        case .captain: return "captain_america"
        case .iron: return "iron_man"
        case .spider: return "spider_man"
        case .thor: return "thor"
        case .mercedes: return "mercedes"
        case .audi: return "audi"
        case .bmw: return "bmw"
        }
    }
}

protocol IRecognizerPresenter {
    var modelType: ModelType { get set }
    
    func viewDidLoad()
    func didTapChangeModelTypeButton()
    func videoDidCaptured(_ pixelBuffer: CVImageBuffer)
}

final class RecognizerPresenter: IRecognizerPresenter {
    
    // Models
    var modelType: ModelType = .imageClassification
    private var imageClassificationRequests: [VNRequest] = []
    private var objectDetectionRequests: [VNRequest] = []
    weak var view: IRecognizerViewController?
    
    // MARK: - IPresenter
    
    func viewDidLoad() {
        view?.setupTextOnModelTypeButton(text: modelType.buttonText)
        setupVision()
    }
    
    func didTapChangeModelTypeButton() {
        switch modelType {
        case .imageClassification:
            modelType = .objectDetector
            view?.cleanImageClassificationLayers()
        case .objectDetector:
            modelType = .imageClassification
            view?.cleanObjectDetectionLayers()
        }
        view?.setupTextOnModelTypeButton(text: modelType.buttonText)
    }
    
    func videoDidCaptured(_ pixelBuffer: CVImageBuffer) {
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            switch modelType {
            case .imageClassification:
                try imageRequestHandler.perform(imageClassificationRequests)
            case .objectDetector:
                try imageRequestHandler.perform(objectDetectionRequests)
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: - Private
    
    private func setupVision() {
        guard let carsModel = Bundle.main.url(forResource: "cars1000", withExtension: "mlmodelc"),
        let peopleModel = Bundle.main.url(forResource: "ppl6000", withExtension: "mlmodelc")
        else { print("Model is Missing"); return }
        
        do {
            let classificationModel = try VNCoreMLModel(for: MLModel(contentsOf: carsModel))
            let objectDetectionModel = try VNCoreMLModel(for: MLModel(contentsOf: peopleModel))
            
            let imageClassification = VNCoreMLRequest(model: classificationModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    if let results = request.results {
                        self.drawImageClassificetionResult(results)
                    }
                })
            })
            
            let objectRecognition = VNCoreMLRequest(model: objectDetectionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    if let results = request.results {
                        self.drawObjectDetectionResult(results)
                    }
                })
            })
            
            self.imageClassificationRequests = [imageClassification]
            self.objectDetectionRequests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
    }
    
    private func drawImageClassificetionResult(_ results: Any) {
        guard
            let results = results as? [VNClassificationObservation],
            let firstResult = results.first,
            modelType == .imageClassification
            else { view?.cleanImageClassificationLayers(); return }
        
        view?.isImageClassificationLayersCleaned = false
        let formattedString = NSMutableAttributedString(string: String(format: "\(firstResult.identifier)\nConfidence:  %.2f", firstResult.confidence * 100))
        let largeFont = UIFont(name: "Helvetica", size: 17.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: firstResult.identifier.count))
        formattedString.addAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], range: NSRange(location: 0, length: formattedString.string.count))
        let image = detectImage(result: firstResult)
        
        DispatchQueue.main.async {
            self.view?.drawImageClassificationResult(image: image, text: formattedString)
        }
    }
    
    private func drawObjectDetectionResult(_ results: [Any]) {
        guard modelType == .objectDetector, let bufferSize = view?.bufferSize else { view?.cleanObjectDetectionLayers(); return }
        
        view?.isObjectDetectionLayersCleaned = false
        var objectsInfo: [(CGRect, String, Float)] = []
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            let topResult = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox,
                                                            Int(bufferSize.width),
                                                            Int(bufferSize.height))
            let objectIdentifier = topResult.identifier
            let objectConfidence = Float(topResult.confidence)
            
            objectsInfo.append((objectBounds, objectIdentifier, objectConfidence))
        }
        view?.drawObjectDetectionResult(objectsInfo: objectsInfo)
    }
    
    private func detectImage(result: VNClassificationObservation) -> CGImage? {
        if result.identifier.contains("Mercedes") {
            return UIImage(named: "mercedes.png")?.cgImage
        } else if result.identifier.contains("Audi") {
            return UIImage(named: "audi.png")?.cgImage
        } else if result.identifier.contains("BWM") {
            return UIImage(named: "bwm.png")?.cgImage
        }
//        if result.identifier == Result.captain.string {
//            return UIImage(named: "captain.png")?.cgImage
//        } else if result.identifier == Result.iron.string {
//            return UIImage(named: "iron.png")?.cgImage
//        } else if result.identifier == Result.spider.string {
//            return UIImage(named: "spider.png")?.cgImage
//        } else if result.identifier == Result.thor.string {
//            return UIImage(named: "hammer.png")?.cgImage
//        }
        return nil
    }
    
    private func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}
