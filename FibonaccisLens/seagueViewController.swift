//
//  seagueViewController.swift
//  FibonaccisLens
//
//  Created by Allan Shi on 2021/12/8.
//

import UIKit

class seagueViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if isNewUser.shared.isnew() {
            let vc = storyboard?.instantiateViewController(identifier: "welcome") as! WelcomViewController
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
        else {
            let cv = storyboard?.instantiateViewController(identifier: "camera") as! cameraViewController
            cv.modalPresentationStyle = .fullScreen
            present(cv, animated: true)
        }
    }
    
}

class isNewUser{
    
    static let shared = isNewUser()
    
    func isnew() -> Bool {
        return !UserDefaults.standard.bool(forKey: "isNewUser")
    }
    
    func setisNotNew(){
        UserDefaults.standard.set(true, forKey: "isNewUser")
    }
}
