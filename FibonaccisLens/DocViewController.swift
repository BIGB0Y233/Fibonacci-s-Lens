//
//  DocViewController.swift
//  FibonaccisLens
//
//  Created by Allan Shi on 2021/12/6.
//

import UIKit
import CardSlider
import SPPermissions

struct Item:CardSliderItem {
    var image: UIImage
    var rating: Int?
    var title: String
    var subtitle: String?
    var description: String?
}

public var composits = "thirds"

class DocViewController: UIViewController,CardSliderDataSource{
    
    override var shouldAutorotate: Bool{get{return false}}
    
    var vc = CardSliderViewController()
    
    public var numCompleHandler: ((Int?)-> Void)?
    
    @IBAction func exitPage(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBOutlet weak var changeCompositionBtn: UIButton!
    @IBAction func changeComposition(_ sender: Any) {
        present(vc,animated: true)
    }

    @IBOutlet weak var changeCameraParasBtn: UIButton!
    
    @IBAction func changeCameraParas(_ sender: Any) {
        print(composits)
    }
    @IBOutlet weak var privicyCheckBtn: UIButton!
    @IBAction func checkPrivicy(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(identifier: "welcome") as! WelcomViewController
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    
    var data = [Item]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        data.append(Item(image: UIImage(named: "thirdsExp")!,
                         rating: nil,
                         title: "三分法",
                         subtitle: "三等分切割画面，构造视觉中心",
                         description: "使模特的面部位于网格线相交处，或使眼睛位于上方的线附近。"))

        data.append(Item(image: UIImage(named: "goldenExp")!,
                         rating: nil,
                         title: "黄金分割",
                         subtitle: "用黄金比例切割画面，构造视觉中心",
                         description: "使模特的面部位于网格线相交处，或使眼睛位于上方的线附近。"))

        data.append(Item(image: UIImage(named: "thirds")!,
                         rating: nil,
                         title: "更多模式开发中",
                         subtitle: "请等待更新发布",
                         description: ":)"))
        
        vc = CardSliderViewController.with(dataSource: self)
        vc.title = "选择你的构图偏好"
        vc.modalPresentationStyle = .fullScreen
        vc.completionHandler = {text in
            composits = text!
        }
        switch composits{
        case "thirds": numCompleHandler?(2)
        case "golden": numCompleHandler?(1)
        default:numCompleHandler?(2)
        }
        
        let btn = UIButton(frame: CGRect(x: 306.3, y: 65, width: 52.67, height: 31))
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = .link
        btn.setTitle("完成", for: .normal)
        btn.layer.cornerRadius = 5
        btn.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
        vc.view.addSubview(btn)
        CustomizeView(view: changeCompositionBtn)
        CustomizeView(view: changeCameraParasBtn)
        CustomizeView(view: privicyCheckBtn)
    }
    
    @objc func didTap(_ button:UIButton)
    {
        self.dismiss(animated: true, completion: nil)
    }
    
    func item(for index: Int) -> CardSliderItem {
        return data[index]
    }
    
    func numberOfItems() -> Int {
        return data.count
    }
    
    
}
