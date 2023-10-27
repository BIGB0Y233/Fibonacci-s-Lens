//
//  cameraViewController.swift
//  test view controller
//
//  Created by Allan Shi on 2021/9/22.
//
import UIKit
import AVFoundation
import CoreLocation
import Photos
import Vision
import Combine
import SPPermissions



public var selectedFormatIndex1 = 43
public var selectedFormatIndex2 = 41
public enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}
public var setupResult: SessionSetupResult = .notAuthorized


class cameraViewController: UIViewController{
    

    enum parts: Int {
        case skin = 1
        case nose = 10
        case l_eye = 4
        case r_eye = 5
        case mouth = 11
    }
    
    struct composotionpoints {
        var leftUp = CGPoint()
        var rightUp = CGPoint()
        var left = CGPoint()
        var right = CGPoint()
        var middle = CGPoint()
    }
    
    // MARK: - UI Properties
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var GridView: UIImageView!
    var preview: CALayer!
    var videoPreview:AVCaptureVideoPreviewLayer!
    var points = composotionpoints()
    var isGirdDisabled: Bool = true

    @IBOutlet weak var docs: UIButton!


    
    @IBOutlet weak var zoomSlider: UISlider!
    @IBAction func zoomCamera(_ sender: UISlider) {
        do {
            try videoCapture.videoDeviceInput.device.lockForConfiguration()
            videoCapture.videoDeviceInput.device.videoZoomFactor = CGFloat(zoomSlider.value)
            videoCapture.videoDeviceInput.device.unlockForConfiguration()
        } catch {
            print("Could not lock for configuration: \(error)")
        }
    }

    @IBOutlet weak var AnalyzeButton: UIButton!
    @IBAction func Analyze(_ sender: UIButton) {
        AnalyzeButton.setBackgroundImage(#imageLiteral(resourceName: "Bulb2"), for: [])
        AnalyzeButton.isEnabled = false
        if modes != getOrientation(){
            modes = getOrientation()
            videoCapture.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = modes
        }
        isSampling = true
        number1 = number
    }

    @IBOutlet weak var libraryPreview: UIButton!
    @IBOutlet weak var judgingDot: UIImageView!
    // MARK: - sampling properties
    var cancellables: Set<AnyCancellable>? = []
    let timePublisher = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    var number:Int=0
    var number1 = 0
    var isSampling = false
    var isJudging = false

    var isInferencing = false
    // MARK: - Vision Properties
    var segmentationRequest: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    var detectionRequest: VNDetectFaceRectanglesRequest?
    var faceRectHistory: [CGRect] = []
    let maximumFaceRectNumber = 7 // optimized in iPhone 11 Pro device
    var RatioChanged = false
    var shouldHidRect = true
    // MARK: - AV Properties
    var videoCapture: VideoCapture!
    var cameraTexture: Texture?
    var cameraTextureGenerater = CameraTextureGenerater()
    var croppedTextureGenerater = CroppedTextureGenerater()
    var modes:AVCaptureVideoOrientation = .portrait
    private let locationManager = CLLocationManager()
    var lastPoint = CGPoint(x: 0, y: 0)
    var judgementRow = 0
    var judgementCol = 0
    var selectedFormatIndex: Int!
    //MARK: - Animation Properties
    var isOnCount = 0
    var isOffCount = 0
    var hasBeenInvalid = false
    // MARK: - FaceParsing(iOS14+)
    /// - labels:  ["background", "skin", "l_brow", "r_brow", "l_eye", "r_eye", "eye_g", "l_ear", "r_ear", "ear_r", "nose", "mouth", "u_lip", "l_lip", "neck", "neck_l", "cloth", "hair", "hat"]
    /// - number of labels: 19
    @available(iOS 14.0, *)
    lazy var segmentationModel: FaceParsing = {
        let model = try! FaceParsing()
        return model
    }()
    // MARK: - View Controller Life Cycle
    // disable auto rotation
    override var shouldAutorotate: Bool{get{return false}}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Disable the UI. Enable the UI later, if and only if the session starts running
        photoButton.isEnabled = false
        livePhotoModeButton.isEnabled = false
        docs.isEnabled = false
        judgingDot.isHidden = true
        AnalyzeButton.isEnabled = false
        libraryPreview.isEnabled = false
        GridView.alpha = 0.0
        
        let authoring = SPPermissions.Permission.camera.status
        
        if authoring != .authorized {
            callPermission()
        }
        
        // Request location authorization so photos can be tagged with their location.
        if #available(iOS 14.0, *) {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
        } else {
            // Fallback on earlier versions
        }
        /*
         Check the video authorization status.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            setupResult = .success
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             */
            sessionQueue.suspend()
            
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
        
        setUpCamera()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.async {
            
            self.videoCapture.configureSession()
            
            switch setupResult {
            case .success:
                self.videoCapture.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = self.modes
                // Only setup observers and start the session if setup succeeded.
                self.addObservers()
                do {
                    try self.videoCapture.videoDeviceInput.device.lockForConfiguration()
                    self.videoCapture.videoDeviceInput.device.activeFormat = self.videoCapture.videoDeviceInput.device.formats[selectedFormatIndex1]
                    self.videoCapture.videoDeviceInput.device.videoZoomFactor = 2.1851265
                    self.videoCapture.videoDeviceInput.device.unlockForConfiguration()
                } catch {
                    setupResult = .configurationFailed
                    print("Could not lock for configuration: \(error)")
                }
                self.videoCapture.session.startRunning()
                self.isSessionRunning = self.videoCapture.session.isRunning
        
            case .notAuthorized:
                    DispatchQueue.main.async {
                                        let changePrivacySetting = "We don't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    
//                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
//                                                            style: .cancel,
//                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
        videoPreview = AVCaptureVideoPreviewLayer(session: self.videoCapture.session)
        self.preview = videoPreview
        self.previewView.layer.addSublayer(self.preview)
        self.preview.frame = self.previewView.layer.frame

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //Set Up Core ML Model
        setUpModel()
        AnalyzeButton.isEnabled = true
        timePublisher.sink { _ in
            self.number+=1
           // print(self.number)
            self.isJudging=true
       }.store(in: &self.cancellables!)
        let urlString = NSHomeDirectory()+"/Documents/indexData"
        let fileUrl = URL(fileURLWithPath: urlString)
        createFolder(baseUrl: urlString)
        createTxt(name:"data.txt", fileBaseUrl: fileUrl)
        write(string: "2", name: "data.txt",docPath: fileUrl)
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        print("ViewDisappeared")
        sessionQueue.async {
            if setupResult == .success {
                self.videoCapture.session.stopRunning()
                self.isSessionRunning = self.videoCapture.session.isRunning
                self.removeObservers()
            }
        }
        super.viewWillDisappear(animated)
    }

    // MARK: - Setup Core ML
    func setUpModel() {
        self.detectionRequest = VNDetectFaceRectanglesRequest()
        // face parsing semantic segmentation
        if #available(iOS 14.0, *) {
            if let visionModel = try? VNCoreMLModel(for: segmentationModel.model) {
                self.visionModel = visionModel
                segmentationRequest = VNCoreMLRequest(model: visionModel)
                segmentationRequest?.imageCropAndScaleOption = .scaleFit
            } else {
                fatalError()
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    //MARK: - Setup Camera
    func setUpCamera() {
        //set up camera
        videoCapture = VideoCapture()
        //videoCapture.session.sessionPreset = .photo
        videoCapture.delegate = self
    }
    // MARK: - Session Management

    private var isSessionRunning = false

    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    @IBAction private func resumeInterruptedSession(_ resumeButton: UIButton) {
        sessionQueue.async {
            /*
             The session might fail to start running, for example, if a phone or FaceTime call is still
             using audio or video. This failure is communicated by the session posting a
             runtime error notification. To avoid repeatedly failing to start the session,
             only try to restart the session in the error handler if you aren't
             trying to resume the session.
             */
            self.videoCapture.session.startRunning()
            self.isSessionRunning = self.videoCapture.session.isRunning
            if !self.videoCapture.session.isRunning {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
                    let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            }else {
                DispatchQueue.main.async {
                    self.resumeButton.isHidden = true
                }
            }
        }
    }

    
    // MARK: Device Configuration
    @IBAction private func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let devicePoint = videoPreview.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }

    @IBOutlet private weak var cameraUnavailableLabel: UILabel!
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera, .builtInDualWideCamera],
                                                                               mediaType: .video, position: .unspecified)
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        
        sessionQueue.async {
            let device = self.videoCapture.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                /*
                 Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                 Call set(Focus/Exposure)Mode() to apply the new point of interest.
                 */
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    // MARK: Capturing Photos
    
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    var videoTextureCache: CVMetalTextureCache?
    
    @IBOutlet private weak var photoButton: UIButton!
    
    func getOrientation() -> AVCaptureVideoOrientation {
        if !UIDevice.current.isGeneratingDeviceOrientationNotifications{
        UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
        var neworientation:AVCaptureVideoOrientation = .portrait
        
        if UIDevice.current.orientation == .portrait{
            neworientation = .portrait
        }
        if UIDevice.current.orientation == .landscapeLeft {
            neworientation = .landscapeRight
        }
        if UIDevice.current.orientation == .landscapeRight {
            neworientation = .landscapeLeft
        }
        return neworientation
    }
    /// - Tag: CapturePhoto
    @IBAction private func capturePhoto(_ photoButton: UIButton) {

        let authorizeStatus = SPPermissions.Permission.photoLibrary.status
        if authorizeStatus != .authorized
        {

            DispatchQueue.main.async {
                let changePrivacySetting = "We don't have permission to access photo library and can not save photos.Please change privacy settings."
                let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to photo library")
                let alertController = UIAlertController(title: "Privicy Denied", message: message, preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                        style: .cancel,
                                                        handler: nil))
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                        style: .`default`,
                                                        handler: { _ in
                                                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                      options: [:],
                                                                                      completionHandler: nil)
                }))
                
                self.present(alertController, animated: true, completion: nil)
            }
            return
        }
        
        sessionQueue.async {
            let neworientation = self.getOrientation()
            
            print(neworientation.rawValue)
            
            self.videoCapture.photoOutput.connection(with: .video)?.videoOrientation = neworientation
            
            var photoSettings = AVCapturePhotoSettings()
            
            // Capture HEIF photos when supported. Enable auto-flash and high-resolution photos.
            if  self.videoCapture.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.videoCapture.videoDeviceInput.device.isFlashAvailable {
                    photoSettings.flashMode = .off
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
            }
            // Live Photo capture
            if livePhotoMode == .on && self.videoCapture.photoOutput.isLivePhotoCaptureSupported {
                let livePhotoMovieFileName = NSUUID().uuidString
                let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
                
                photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
            }
            
            photoSettings.photoQualityPrioritization = .quality
            
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, willCapturePhotoAnimation: {
                // Flash the screen to signal that took a photo.
                DispatchQueue.main.async {
                    self.previewView.alpha=0
                    UIView.animate(withDuration: 1) {
                        self.previewView.alpha = 1
                    }
                }
            }, livePhotoCaptureHandler: { capturing in
                self.sessionQueue.async {
                    if capturing {
                        self.inProgressLivePhotoCapturesCount += 1
                    } else {
                        self.inProgressLivePhotoCapturesCount -= 1
                    }
                }
            }, completionHandler: { photoCaptureProcessor in
                // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                self.sessionQueue.async {
                    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                }
            }, photoProcessingHandler: { _ in
            }
            )
            
            // Specify the location the photo was taken
            photoCaptureProcessor.location = self.locationManager.location
            
            // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            self.videoCapture.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }
        
    @IBOutlet private weak var livePhotoModeButton: UIButton!
    
    @IBAction private func toggleLivePhotoMode(_ livePhotoModeButton: UIButton) {
                DispatchQueue.main.async {
                    livePhotoMode = (livePhotoMode == .on) ? .off : .on
                    let livePhotoMode = livePhotoMode
                    if livePhotoMode == .on {
                        self.livePhotoModeButton.setImage(#imageLiteral(resourceName: "LivePhotoON"), for: [])
                    } else {
                        self.livePhotoModeButton.setImage(#imageLiteral(resourceName: "LivePhotoOFF"), for: [])
                    }
                }
    }
    
    @IBOutlet weak var DisableGridButton: UIButton!
    
    @IBAction func toggleDisableGrid(_ sender: Any) {
        
        if !isGirdDisabled{
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear, animations: {
                self.GridView.alpha = 0.0
            })
            self.DisableGridButton.setBackgroundImage(#imageLiteral(resourceName: "GridOff"), for: [])
        }
        else{
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear, animations: {
                self.GridView.alpha = 1.0
            })
            self.DisableGridButton.setBackgroundImage(#imageLiteral(resourceName: "GridOn"), for: [])
        }
        isGirdDisabled.toggle()
    }
    
    @IBOutlet weak var selectRatio: UISegmentedControl!
    @IBAction func RatioDidChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            RatioChanged = false
            selectedFormatIndex = selectedFormatIndex1
            GridView.transform = CGAffineTransform.identity
        case 1:
            RatioChanged = true
            selectedFormatIndex = selectedFormatIndex2
            GridView.transform = CGAffineTransform(scaleX: 1, y: 1.334)
        default:
            break
        }
        self.zoomSlider.value = 2.1851265
        do {
            try videoCapture.videoDeviceInput.device.lockForConfiguration()
            videoCapture.videoDeviceInput.device.activeFormat = videoCapture.videoDeviceInput.device.formats[selectedFormatIndex]
            videoCapture.videoDeviceInput.device.videoZoomFactor = CGFloat(zoomSlider.value)
            videoCapture.videoDeviceInput.device.unlockForConfiguration()
                } catch {
                    print("input configuration failed!")
                }
        print("the format is:\(videoCapture.videoDeviceInput.device.activeFormat.description)")
        livePhotoMode = .off
        livePhotoModeButton.setImage(#imageLiteral(resourceName: "LivePhotoOFF"), for: [])
        livePhotoModeButton.isEnabled = false
    }
    
  //find ideal formats' info
    func getFormatInfo() {
        let formats = self.videoCapture.videoDeviceInput.device.formats
            for index in 0..<formats.count {
                let format = formats[index]
//                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//                let maxFrameRate = format.videoSupportedFrameRateRanges.last?.maxFrameRate
//                let hdr = format.isVideoHDRSupported
//                  print(dimensions,maxFrameRate,hdr,index)
                print(index,format.description)
            }
    }
    
    private var inProgressLivePhotoCapturesCount = 0
    
    @IBOutlet private weak var resumeButton: UIButton!
    
    // MARK: - KVO and Notifications
 
  public var keyValueObservations = [NSKeyValueObservation]()
    /// - Tag: ObserveInterruption
    private func addObservers() {
        let keyValueObservation = videoCapture.session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            let isLivePhotoCaptureEnabled = self.videoCapture.photoOutput.isLivePhotoCaptureEnabled
            DispatchQueue.main.async {
                self.photoButton.isEnabled = isSessionRunning
                self.livePhotoModeButton.isEnabled = isSessionRunning && isLivePhotoCaptureEnabled
                self.docs.isEnabled = isSessionRunning
                self.libraryPreview.isEnabled = isSessionRunning
                self.selectRatio.isEnabled = isSessionRunning
                self.zoomSlider.isEnabled = isSessionRunning
                self.zoomSlider.maximumValue = Float(min(self.videoCapture.videoDeviceInput.device.activeFormat.videoMaxZoomFactor, CGFloat(8.0)))
                self.zoomSlider.value = 2.1851265 //Float(self.videoCapture.videoDeviceInput.device.videoZoomFactor)
            }
        }
        keyValueObservations.append(keyValueObservation)
        

        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoCapture.videoDeviceInput.device)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: videoCapture.session)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: videoCapture.session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: videoCapture.session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    /// - Tag: HandleRuntimeError
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart the session.
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.videoCapture.session.startRunning()
                    self.isSessionRunning = self.videoCapture.session.isRunning
                } else {
                    DispatchQueue.main.async {
                        self.resumeButton.isHidden = false
                    }
                }
            }
        } else {
            resumeButton.isHidden = false
        }
    }
    
    /// - Tag: HandleSystemPressure
    public func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        /*
         The frame rates used here are only for demonstration purposes.
         Your frame rate throttling may be different depending on your app's camera configuration.
         */
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
                do {
                    try self.videoCapture.videoDeviceInput.device.lockForConfiguration()
                    print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                    self.videoCapture.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
                    self.videoCapture.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
                    self.videoCapture.videoDeviceInput.device.unlockForConfiguration()
                } catch {
                    print("Could not lock device for configuration: \(error)")
                }
        } else if pressureLevel == .shutdown {
            print("Session stopped running due to shutdown system pressure level.")
        }
    }
    
    /// - Tag: HandleInterruption
    @objc
    func sessionWasInterrupted(notification: NSNotification) {
        /*
         In some scenarios you want to enable the user to resume the session.
         */
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
            var showResumeButton = false
            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
                showResumeButton = true
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // Fade-in a label to inform the user that the camera is unavailable.
                cameraUnavailableLabel.alpha = 0
                cameraUnavailableLabel.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.cameraUnavailableLabel.alpha = 1
                }
            } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
                print("Session stopped running due to shutdown system pressure level.")
            }
            if showResumeButton {
                // Fade-in a button to enable the user to try to resume the session running.
                resumeButton.alpha = 0
                resumeButton.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.resumeButton.alpha = 1
                }
            }
        }
    }
    
    @objc
    func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")
        if !resumeButton.isHidden {
            UIView.animate(withDuration: 0.25,
                           animations: {
                            self.resumeButton.alpha = 0
            }, completion: { _ in
                self.resumeButton.isHidden = true
            })
        }
        if !cameraUnavailableLabel.isHidden {
            UIView.animate(withDuration: 0.25,
                           animations: {
                            self.cameraUnavailableLabel.alpha = 0
            }, completion: { _ in
                self.cameraUnavailableLabel.isHidden = true
            }
            )
        }
    }
    
    func callPermission()
    {
        let permissions: [SPPermissions.Permission] = [.camera, .photoLibrary,.locationWhenInUse]
        let controller = SPPermissions.dialog(permissions)
        controller.dismissCondition = .allPermissionsAuthorized
        controller.allowSwipeDismiss = false
        controller.footerText = "Fibonacci's Lens"
        controller.showCloseButton = false
        controller.present(on: self)
    }

}


// MARK: - VideoCaptureDelegate
extension cameraViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        cameraTexture = cameraTextureGenerater.genTexture(from: sampleBuffer)
        DispatchQueue.main.async {
            self.GridView.image = UIImage(named: composits)
            if self.number-self.number1>=8 {
                self.AnalyzeButton.isEnabled = true
                self.AnalyzeButton.setBackgroundImage(#imageLiteral(resourceName: "Bulb"), for: [])
            }
            if self.shouldHidRect{
                self.judgingDot.isHidden = true
            }
            else{
                self.judgingDot.isHidden = false
            }
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                if isJudging {
                    isJudging = false
                    if !isInferencing{
                predict(with: pixelBuffer)
                    }
                }
    }
}
// MARK: - Inference
extension cameraViewController {
    func predict(with pixelBuffer: CVPixelBuffer)
        {
            // ==================================================
            // 1. face detection and rendering cropped face frame
            // ==================================================
            guard !isInferencing else { return }
            isInferencing = true
            
            guard let cameraTexture = cameraTexture
            else{
                isInferencing = false
                return}
            
            guard let request = detectionRequest else
            { isInferencing = false
             return}
            let imageRequestHandler: VNImageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            try? imageRequestHandler.perform([request])
            
            guard let faceDetectionObservations = request.results as? [VNFaceObservation] else {  isInferencing = false
                return }
            
            guard let boundingbox = faceDetectionObservations.map({ $0.boundingBox }).first else {
                shouldHidRect = true
                isInferencing = false
                return
            }
            
                let width = cameraTexture.texture.width
                let height = cameraTexture.texture.height
                
                let cgBoundingBox = CGRect(x: boundingbox.origin.x * CGFloat(width), y: (1-(boundingbox.origin.y + boundingbox.height)) * CGFloat(height), width: boundingbox.width * CGFloat(width), height: boundingbox.height * CGFloat(height)
                )
                let expanedBoundingBox = cgBoundingBox.scaledFromCenterPoint(scaleX: 1.8, scaleY: 1.8)
                
                let fixedBox = fixBox(box: expanedBoundingBox, width: CGFloat(width), height: CGFloat(height))

            faceRectHistory.append(fixedBox)
            if faceRectHistory.count >= maximumFaceRectNumber {
                faceRectHistory.removeFirst()
            }
            let averagedBoundingBox = faceRectHistory.average
            
            guard let croppedFaceTexture = croppedTextureGenerater.genTexture(cameraTexture, fixedBox) else {
                isInferencing = false
                return
            }
            guard let segmentationRequest = segmentationRequest else {  isInferencing = false
                return }
            guard let ciImage = CIImage(mtlTexture: croppedFaceTexture.texture)?.oriented(CGImagePropertyOrientation.down) else { isInferencing = false
                return }
            let segmentationHandler = VNImageRequestHandler(ciImage: ciImage)
            try? segmentationHandler.perform([segmentationRequest])

            guard let segmentationObservations = segmentationRequest.results as? [VNCoreMLFeatureValueObservation],
                  let segmentationmap = segmentationObservations.first?.featureValue.multiArrayValue
            else {  isInferencing = false
                return }
            
            let mySegmentationmap = SegmentationResultMLMultiArray(mlMultiArray: segmentationmap)
            
///save segmentation data
//            let segmentationmapWidthSize = mySegmentationmap.segmentationmapWidthSize
//            let segmentationmapHeightSize = mySegmentationmap.segmentationmapHeightSize
//                        let urlString=NSHomeDirectory()+"/Documents/finalTest"
//                        createFolder(baseUrl: urlString)
//                        let fileUrl = URL(fileURLWithPath: urlString)
//                        createTxt(name:"test\(number).txt", fileBaseUrl: fileUrl)
//                                for j in 0..<segmentationmapHeightSize {
//                                    for i in 0..<segmentationmapWidthSize {
//                                        write(string: "\(mySegmentationmap[j,i].intValue) ", name: "test\(number).txt",docPath: fileUrl)
//                                    }
//                                    write(string: "\n", name: "test\(number).txt",docPath: fileUrl)
//                                }
//                        print("success")
            
            
            ///judging distance
            let ratio = boundingbox.size.height * boundingbox.size.width
            if ratio>0.01{
                judgementRow = 1
            }
            else {
                judgementRow = 2
            }
            
            var judgingPoint: CGPoint
            if isSampling{
                isSampling=false
                judgingPoint = getJudgingPoint(mySegmentationmap: mySegmentationmap)
                lastPoint = judgingPoint
            }
            else {
                judgingPoint = lastPoint
            }
            let coorinates = isWithIn(judging: judgingPoint, within: fixedBox)
            if !coorinates.isEmpty {
        //       print("map\(mySegmentationmap[coorinates[0],coorinates[1]].intValue)")
                if  mySegmentationmap[coorinates[0],coorinates[1]].intValue == parts.nose.rawValue ||
                    mySegmentationmap[coorinates[0],coorinates[1]].intValue == parts.skin.rawValue{
                    isOnCount+=1
                }
            else {
                isOffCount+=1
            }
            }
            else {
                isOffCount+=1
            }
            
            let increLength: Int
            let increCoord: Int
            
           ///vary from devices
            if RatioChanged {
                increLength = 166
                increCoord = 73
            }
            else {
                increLength = 0
                increCoord = 156
            }

            ///GUI position 375 and 500 vary from devices
            DispatchQueue.main.async {
                    if self.number-self.number1>=32{
                        judgingPoint.x = 0
                    }
                if judgingPoint.x == 0{
                    self.shouldHidRect = true
                    return  }
                else {
                    self.shouldHidRect = false
                }

                switch self.modes {
                case .portrait:
                    self.judgingDot.transform = CGAffineTransform(scaleX: averagedBoundingBox.width*CGFloat(375)/CGFloat(width)/100.0, y: averagedBoundingBox.height*CGFloat(500+increLength)/CGFloat(height)/100.0)
                    self.judgingDot.frame.origin.x = 375*judgingPoint.x/CGFloat(width)
                    self.judgingDot.frame.origin.y = CGFloat(500+increLength)*judgingPoint.y/CGFloat(height)
                    self.judgingDot.frame.origin.y += CGFloat(increCoord)-averagedBoundingBox.height*CGFloat(500+increLength)/CGFloat(height)/2.0
                    self.judgingDot.frame.origin.x -= averagedBoundingBox.width*375.0/CGFloat(width)/2.0
                case .landscapeRight:
                    self.judgingDot.transform = CGAffineTransform(scaleX: averagedBoundingBox.height*CGFloat(375)/CGFloat(height)/100.0, y:averagedBoundingBox.width*CGFloat(500+increLength)/CGFloat(width)/100.0)
                    self.judgingDot.frame.origin.x = 375 - 375*judgingPoint.y/CGFloat(height)
                    self.judgingDot.frame.origin.y = CGFloat(500+increLength)*judgingPoint.x/CGFloat(width)
                    self.judgingDot.frame.origin.y += CGFloat(increCoord)-averagedBoundingBox.width*CGFloat(500+increLength)/CGFloat(width)/2.0
                    self.judgingDot.frame.origin.x -= averagedBoundingBox.height*375.0/CGFloat(height)/2.0
                case .landscapeLeft:
                    self.judgingDot.transform = CGAffineTransform(scaleX: averagedBoundingBox.height*CGFloat(375)/CGFloat(height)/100.0, y:averagedBoundingBox.width*CGFloat(500+increLength)/CGFloat(width)/100.0)
                    self.judgingDot.frame.origin.x = 375*judgingPoint.y/CGFloat(height)
                    self.judgingDot.frame.origin.y = CGFloat(500+increLength)-CGFloat(500+increLength)*judgingPoint.x/CGFloat(width)
                    self.judgingDot.frame.origin.y += CGFloat(increCoord)-averagedBoundingBox.width*CGFloat(500+increLength)/CGFloat(width)/2.0
                    self.judgingDot.frame.origin.x -= averagedBoundingBox.height*375.0/CGFloat(height)/2.0
                default:
                    print("unrecognizable orientation")
                }
               //-------------
               //animation
               //--------------
                if self.isOnCount>=5{
                    self.isOnCount = 0
                    self.isOffCount = 0
                    if self.hasBeenInvalid {
                        //vibrate
                        self.judgingDot.tintColor = UIColor.red
                        AudioServicesPlaySystemSound(1520)
                    }
                    self.hasBeenInvalid = false
                }
                
                if self.isOffCount>=3 {
                    self.judgingDot.tintColor = UIColor.white
                    self.hasBeenInvalid = true
                     }
            }
            isInferencing = false
    }
    
    
    func getJudgingPoint(mySegmentationmap:SegmentationResultMLMultiArray) -> CGPoint{
       
        guard let cameraTexture = cameraTexture
        else {print("camera went wrong")
            return CGPoint(x: 0, y: 0)}
        let width = cameraTexture.texture.width
        let height = cameraTexture.texture.height
        
                let segmentationmapWidthSize = mySegmentationmap.segmentationmapWidthSize
                let segmentationmapHeightSize = mySegmentationmap.segmentationmapHeightSize
                var isSeperated:Bool = false
                var lsize:Int = 0
                var rsize:Int = 0
                var size: Int = 0
        
                   ///judging face direction loop
                for j in 0..<segmentationmapHeightSize {
                        for i in 0..<segmentationmapWidthSize {
                            if mySegmentationmap[j,i].intValue == parts.skin.rawValue {size+=1}
                            if mySegmentationmap[j,i].intValue == parts.nose.rawValue {
                                isSeperated=true
                                lsize+=size
                                size=0
                            }
                        }
                        if isSeperated {
                            rsize+=size
                            isSeperated=false
                        }
                        size=0
                    }
                   
                    if lsize>rsize+5000 {
                        judgementCol = 2
                    }
                   else if rsize>lsize+5000 {
                        judgementCol = 1
                    }
                    else {
                        judgementCol = 0
                        }
         
                    //-------------
                    //position judgement
                    //--------------
                    var judgingPoint: CGPoint
                    switch composits {
                    case "thirds":
                        points.leftUp = CGPoint(x: width/3, y: height/3)
                        points.left = CGPoint(x: width/3, y: height*2/3)
                        points.rightUp = CGPoint(x: 2*width/3, y: height/3)
                        points.right = CGPoint(x: 2*width/3, y: height*2/3)
                        points.middle = CGPoint(x: width/2, y: height/3)
                    case "golden":
                        points.leftUp = CGPoint(x: Double(width)/2.618, y: Double(height)/2.618)
                        points.left = CGPoint(x: Double(width)/2.618, y: Double(height)*1.618/2.618)
                        points.rightUp = CGPoint(x: Double(width)*1.618/2.618,y: Double(height)/2.618)
                        points.right = CGPoint(x: Double(width)*1.618/2.618, y: Double(height)*1.618/2.618)
                        points.middle = CGPoint(x: Double(width)/2, y: Double(width)/2.618)
                    default:
                        break
                    }
                    switch [judgementRow,judgementCol] {
                    case [1,1]: judgingPoint = points.leftUp
                    case [1,2]: judgingPoint = points.rightUp
                    case [2,1]: judgingPoint = points.left
                    case [2,2]: judgingPoint = points.right
                    default:
                        judgingPoint = points.middle
                    }
        return judgingPoint
    }
    
    func coordTransition(cur:CGRect, holderWidth:CGFloat, holderheight:CGFloat) -> CGRect {
        let tx = holderWidth - cur.origin.x - cur.width
        let ty = holderheight - cur.origin.y - cur.height
        return CGRect(x: tx, y: ty, width: cur.width, height: cur.height)
    }
    
    func fixBox(box:CGRect,width: CGFloat,height: CGFloat) -> CGRect {
        var newX = box.origin.x
        var newY = box.origin.y
        var newWidth = box.width
        var newHeight = box.height
        if newX<0 {
            newX = 0
        }
        if newY<0 {
            newY = 0
        }
        if newX + newWidth > width  {
            newWidth = width - newX
        }
        if newY + newHeight > height  {
            newHeight = height - newY
        }
        return CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
    }
    
    func isWithIn(judging: CGPoint, within: CGRect) -> [Int] {
    let x = judging.x
    let y = judging.y
    let x1 = within.origin.x
    let x2 = x1 + within.width
    let y1 = within.origin.y
    let y2 = y1 + within.height
    if (x>x1 && x<x2) && (y>y1 && y<y2) {
        return [Int(x-x1) * 512 / Int(within.width) , Int(y-y1) * 512 / Int(within.height)]
    }
    else{
        return[]
    }
}
    func createTxt(name:String, fileBaseUrl:URL){
        let manager = FileManager.default
        let file = fileBaseUrl.appendingPathComponent(name)
        print("文件: \(file)")
        let exist = manager.fileExists(atPath: file.path)
        if !exist {
            let data = Data(base64Encoded:"",options:.ignoreUnknownCharacters)
            let createSuccess = manager.createFile(atPath: file.path,contents:data,attributes:nil)
            print("文件创建结果: \(createSuccess)")
        }
    }

    func createFolder(baseUrl:String)
    {   let manager = FileManager.default
        let exist = manager.fileExists(atPath: baseUrl)
        if !exist{
        do {try manager.createDirectory(atPath: baseUrl, withIntermediateDirectories: true, attributes: nil)}
        catch{print("error to create folder!")}
    }
    }

    func write(string:String,name:String,docPath:URL){
        let file = docPath.appendingPathComponent(name)
        let appendedData = string.data(using: String.Encoding.utf8, allowLossyConversion: true)
        let writeHandler = try? FileHandle(forWritingTo:file)
    //    writeHandler?.seekToEndOfFile()
        writeHandler?.write(appendedData!)
    }
}

extension CGRect {
    var centerPoint: CGPoint {
        return CGPoint(x: origin.x + size.width/2, y: origin.y + size.height/2)
    }
    
    func scaledFromCenterPoint(scaleX: CGFloat, scaleY: CGFloat) -> CGRect {
        let newWidth = (size.width * scaleX)
        let newHeight = (size.height * scaleY)
        return CGRect(x: centerPoint.x - newWidth/2, y: centerPoint.y - newHeight/2, width: newWidth, height: newHeight)
    }
}

extension Array where Element == CGRect {
    var average: CGRect {
        let x1y1x2y2 = reduce((0.0, 0.0, 0.0, 0.0)) {
            return ($0.0 + $1.origin.x, $0.1 + $1.origin.y, $0.2 + $1.origin.x + $1.size.width, $0.3 + $1.origin.y + $1.size.height)
        }
        return CGRect(origin: CGPoint(x: x1y1x2y2.0 / CGFloat(count), y: x1y1x2y2.1 / CGFloat(count)),
                      size: CGSize(width: (x1y1x2y2.2 - x1y1x2y2.0) / CGFloat(count), height: (x1y1x2y2.3 - x1y1x2y2.1) / CGFloat(count)))
    }
}


