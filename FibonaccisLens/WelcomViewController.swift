//
//  WelcomViewController.swift
//  Fibonacci's Lens
//
//  Created by Allan Shi on 2021/10/24.
//

import UIKit
import SPPermissions

class WelcomViewController: UIViewController {
    
    var shouldPresent = false
    var astsing: String!
    override var shouldAutorotate: Bool{get{return false}}
    var thecompletion: (()-> Void)?
    @IBOutlet weak var holderView: UIView!
    var scrollView: UIScrollView!
    override func viewDidLoad() {
        super.viewDidLoad()
        CustomizeView(view: holderView)
        // Do any additional setup after loading the view.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        let cv = storyboard?.instantiateViewController(identifier: "camera") as! cameraViewController
//        cv.modalPresentationStyle = .fullScreen
//        present(cv, animated: true, completion: nil)
        configure()
    }
    
    private func configure(){
        
        scrollView = UIScrollView(frame: holderView.bounds)
        CustomizeView(view: scrollView)
        holderView.addSubview(scrollView)
        

        let titles = ["Welcome","Check Privacy","Permission Determined"]
        let pageColors: [UIColor] = [UIColor.init(red: 199/255, green: 155/255, blue: 211/255, alpha: 1),UIColor.init(red: 191/255, green: 242/255, blue: 200/255, alpha: 1),UIColor.init(red: 118/255, green: 194/255, blue: 239/255, alpha: 1)]
        let images = ["ob1","ob2","ob3"]
        
        for i in 0..<3 {
            let pageView = UIView(frame: CGRect(x: CGFloat(i) * holderView.frame.size.width, y: 0, width: holderView.frame.size.width, height: holderView.frame.size.height))
            scrollView.addSubview(pageView)
            pageView.backgroundColor = pageColors[i]
            
            let label = UILabel(frame: CGRect(x: 20, y: 20, width: pageView.frame.size.width-20, height: 120))
            let imageView = UIImageView(frame: CGRect(x: 20, y: 10+120+10, width: pageView.frame.size.width-40, height: pageView.frame.size.height-60-130-15))
            let nextButton = UIButton(frame: CGRect(x: 10, y: pageView.frame.size.height-60, width: pageView.frame.size.width-20, height: 50))
            
            label.textAlignment = .center
            label.textColor = .black
            label.font = UIFont(name: "Helvetica", size: 25)
            label.text = titles[i]
            pageView.addSubview(label)
            
            imageView.contentMode = .scaleAspectFit
            imageView.image = UIImage(named: images[i])
            CustomizeView(view: imageView)
            pageView.addSubview(imageView)
            
            nextButton.setTitleColor(.white, for: .normal)
            nextButton.backgroundColor = .gray
            nextButton.setTitle("Continue", for: .normal)
            if i==1{
                nextButton.setTitle("Check Privicy", for: .normal)
            }
            if i==2 {
                nextButton.setTitle("Start", for: .normal)
            }
            nextButton.tag = i+1
            nextButton.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            CustomizeView(view: nextButton)
            pageView.addSubview(nextButton)
        }
        
        scrollView.contentSize = CGSize(width: holderView.frame.size.width * 3, height: 0)
        scrollView.isPagingEnabled = true        

    }
    
    @objc func didTap(_ button:UIButton)
    {
        if button.tag == 2 {
            callPermission()
        }
        
        if button.tag == 3{
         if isNewUser.shared.isnew(){
             isNewUser.shared.setisNotNew()
             let cv = storyboard?.instantiateViewController(identifier: "camera") as! cameraViewController
             cv.modalPresentationStyle = .fullScreen
             present(cv, animated: true, completion: nil)}
            else{
                self.dismiss(animated: true, completion: nil)
            }
           // self.dismiss(animated: true, completion: nil)
        }
        scrollView.setContentOffset(CGPoint(x: holderView.frame.size.width * CGFloat(button.tag), y: 0), animated: true)
    }
    
    func callPermission()
    {
        let permissions: [SPPermissions.Permission] = [.camera, .photoLibrary,.locationWhenInUse]
        let controller = SPPermissions.dialog(permissions)
        controller.dismissCondition = .allPermissionsDeterminated
        controller.allowSwipeDismiss = true
        controller.footerText = "Swipe to Dismiss"
        controller.showCloseButton = false
        controller.present(on: self)
    }
    
}


public func CustomizeView(view:UIView) {
    view.layer.cornerRadius = 20
//    view.layer.shadowRadius = 1
//    view.layer.shadowOpacity = 1.0
//    view.layer.shadowOffset = CGSize(width: 2, height: 2)
}
