//
//  DetailViewController.swift
//  Coq4iOS
//
//  Created by 後藤宗一朗 on 2018/11/05.
//  Copyright © 2018年 後藤宗一朗. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    
    let stringAttributes: [NSAttributedStringKey : Any] = [
        .foregroundColor : UIColor.orange,
        .font : UIFont.systemFont(ofSize: 40.0)
    ]
    let stringAttributesN: [NSAttributedStringKey : Any] = [
        .foregroundColor : UIColor.black,
        .font : UIFont.systemFont(ofSize: 40.0)
    ]
    
    let mutableAttributedString = NSMutableAttributedString()
    
    func configureView() {
        // Update the user interface for the detail item.
        if let detail = detailItem {
            if let label = detailDescriptionLabel {
                label.text = detail.description
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        configureView()
        startCoq()
        readStdout({(msg:String?) -> Void in
            fputs(msg, stderr)
            NSLog("ppai")
        });
        let goalAreaController = childViewControllers[0] as! GoalAreaViewController
        eval("Goal forall (A B C : Prop),(B -> C) -> (A -> B) -> (A -> C).", {(res:Bool, ans:String?) -> Void in
            fputs(ans, stderr);
            goalAreaController.textView.text = ans!

//            let textAdd = NSAttributedString(string: "Theorem modus_ponens: forall (A B: Prop), (A -> B) -> A -> B.", attributes:self.stringAttributes)
            let textAdd = NSAttributedString(string: "Goal forall (A B C : Prop),(B -> C) -> (A -> B) -> (A -> C).", attributes:self.stringAttributes)
            let newLine = NSAttributedString(string: " \n ", attributes:self.stringAttributesN)
            self.mutableAttributedString.append(textAdd)
            self.mutableAttributedString.append(newLine)
            self.scriptArea.attributedText = self.mutableAttributedString
        });
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var detailItem: NSDate? {
        didSet {
            // Update the view.
            configureView()
        }
    }



    @IBOutlet weak var goalArea: UIView!

    @IBOutlet weak var scriptArea: UITextView!
    @IBOutlet weak var readButton: UIButton!
    
    var textFieldString = ""
    
    @IBAction func runAction(_ sender: Any) {
//        let allText = scriptArea.text! as NSString
//        let currentLine = allText.substring(with: allText.lineRange(for: scriptArea.selectedRange))
//        NSLog("text= " + currentLine)
//
//        let array = allText.components(separatedBy: ".")
        
        NSLog("text = \(scriptArea.text)")
        // 親から Container View への受け渡し
//        let goalAreaController = childViewControllers[0] as! GoalAreaViewController
//        eval(array[0], {(res:Bool, ans:String?) -> Void in
//            fputs(ans, stderr);
//            goalAreaController.textView.text = ans!
//        });
    }
    
    func setViewController(str: String){
        // 親から Container View への受け渡し
        let goalAreaController = childViewControllers[0] as! GoalAreaViewController
        eval(str, {(res:Bool, ans:String?) -> Void in
            fputs(ans, stderr);
            goalAreaController.textView.text = ans!
        });

    }

    
}

