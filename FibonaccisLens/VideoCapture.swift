//
//  PhotoCapture.swift
//  test view controller
//
//  Created by Allan Shi on 2021/9/21.
//

import UIKit
import AVFoundation
import CoreVideo

public var myformatIndex: Int  = 0

public protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ capture: VideoCapture,didCaptureVideoSampleBuffer: CMSampleBuffer)
}

//MARK: - status propertites

public enum LivePhotoMode {
    case on
    case off
}
public var livePhotoMode: LivePhotoMode = .off


//public var photoQualityPrioritizationMode: AVCapturePhotoOutput.QualityPrioritization = .quality

//MARK: - video capture session class

public class VideoCapture:NSObject{
    
   public weak var delegate: VideoCaptureDelegate?
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    var videoTextureCache: CVMetalTextureCache?
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    public var previewLayer: AVCaptureVideoPreviewLayer?
    let queue = DispatchQueue(label: "camera-queue")
    // Call this on the session queue.
    
    /// - Tag: ConfigureSession
    func configureSession()
    {
        if setupResult != .success {
            return
        }
        session.beginConfiguration()
    
        // MARK:- Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let trippleCameraDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
                // iPhone 13/12 Pro
                defaultVideoDevice = trippleCameraDevice
            } else
            if let dualWideCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                // iPhone 13/12, 13/12 mini, 11
                defaultVideoDevice = dualWideCameraDevice
            } else
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // others
                defaultVideoDevice = backCameraDevice }

            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
//             session.sessionPreset = .photo
            
            let formats = videoDeviceInput.device.formats
                for index in 0..<formats.count {
                    let format = formats[index]
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    let multicam = format.isMultiCamSupported
                    let hdr = format.isVideoHDRSupported
                    if dimensions.width * dimensions.height == 12192768 {
                        selectedFormatIndex1 = index
                    }
                    if dimensions.width * dimensions.height == 8294400 && multicam && hdr{
                        selectedFormatIndex2 = index
                    }
                }
                          
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // MARK:- Add output.
        let settings: [String : Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        
        videoOutput.videoSettings = settings
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            setUpPhotoOutput()
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        }
        else{print("Could not add video output to the session")}
        
        session.commitConfiguration()
    }
    
    func setUpPhotoOutput(){
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        photoOutput.maxPhotoQualityPrioritization = .quality
        livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
    }
    
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.videoCapture(self, didCaptureVideoSampleBuffer: sampleBuffer)
    }
}
