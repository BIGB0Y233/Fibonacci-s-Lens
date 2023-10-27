

import Photos
import UIKit
import SPPermissions

class PhotoLibraryViewController: UIViewController
    {
    
    override var shouldAutorotate: Bool{get{return false}}
    
    @IBAction func exit(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func changeP(_ sender: Any) {
        getImage(fromSourceType: .photoLibrary)
    }
    let imageview = UIImageView(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let authorizeStatus = SPPermissions.Permission.photoLibrary.status
        if authorizeStatus != .authorized
        {

            DispatchQueue.main.async {
                let changePrivacySetting = "We don't have permission to access photo library and can not view photos.Please change privacy settings."
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

        view.addSubview(imageview)
        getImage(fromSourceType: .photoLibrary)
        // Do any additional setup after loading the view.
    }

}

extension PhotoLibraryViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    //get image from source type
    private func getImage(fromSourceType sourceType: UIImagePickerController.SourceType) {

        //Check is source type available
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {

            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = sourceType
            self.present(imagePickerController, animated: true, completion: nil)
        }
    }

    //MARK:- UIImagePickerViewDelegate.
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        self.dismiss(animated: true) { [weak self] in

            guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
            //Setting image to your image view
            self?.imageview.contentMode = .scaleAspectFit
            self?.imageview.image = image
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }

}

