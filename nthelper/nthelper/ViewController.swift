//
//  ViewController.swift
//  nthelper
//
//  Created by wyw on 2022/9/2.
//

import UIKit
import WebKit
import Photos

class ViewController: UIViewController, WKNavigationDelegate {

    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var webView: WKWebView!
    
    var user: String? = UserDefaults.standard.string(forKey: "_USER")
    var pswd: String? = UserDefaults.standard.string(forKey: "_PSWD")
    
    var pageLoaded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        topView.backgroundColor = .systemBackground
        bottomView.backgroundColor = .systemBackground
        makeRoundedShadow(topView)
        makeRoundedShadow(bottomView)
        webView.navigationDelegate = self
        view.sendSubviewToBack(webView)
        topView.layer.cornerRadius = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !pageLoaded {
            webView.load(URLRequest(url: URL(string: "http://wj.shanghaitech.edu.cn/user/qlist.aspx?sysid=159110074")!))
            pageLoaded = true
        }
    }
    
    func makeRoundedShadow(_ target: UIView) {
        target.layer.shadowColor = UIColor.black.cgColor
        target.layer.shadowRadius = 6
        target.layer.shadowOpacity = 0.3
        target.layer.shadowOffset = CGSize(width: 0, height: 3)
        target.layer.borderColor = UIColor.clear.cgColor
        target.layer.borderWidth = 0.001
        target.layer.cornerRadius = 20
    }
    
    @IBAction func reloadAction(_ sender: Any) {
        self.webView.reload()
        //webView.load(URLRequest(url: URL(string: "http://wenjuan.shanghaitech.edu.cn/user/qlist.aspx?sysid=184502370")!))
    }
    
    @IBAction func userAcc(_ sender: Any) {
        let alert = UIAlertController(title: "当前用户: \(user ?? "未登录")", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "更改账号", style: .default) {_ in
            let accalert = UIAlertController(title: "登录", message: nil, preferredStyle: .alert)
            accalert.addTextField {textField in
                textField.text = self.user
                textField.placeholder = "学号"
            }
            accalert.addTextField {textField in
                textField.text = self.pswd
                textField.placeholder = "密码"
            }
            accalert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            accalert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
                self.user = accalert.textFields![0].text
                self.pswd = accalert.textFields![1].text
                UserDefaults.standard.set(self.user, forKey: "_USER")
                UserDefaults.standard.set(self.pswd, forKey: "_PSWD")
                self.reloadAction(0)
            })
            self.present(accalert, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("----- finish")
        //runJS("document.getElementById('register-user-name').value") { msg, err in
            //print(msg != nil)
        //}
        webLogin(0)
        webSelect(0)
        webFill(0)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("----- commit")
    }
    
    func runJS(_ script: String, handler: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: handler)
    }
    
    @IBAction func webLogin(_ sender: Any) {
        print("+ login action")
        runJS("document.getElementsByClassName('')[0].style.display='none'")
        runJS("document.getElementById('register-user-name').value=\(user ?? "")")
        runJS("document.getElementById('register-user-password').value=\(pswd ?? "")")
        runJS("document.getElementById('btnSubmit').click()")
    }
    
    @IBAction func webSelect(_ sender: Any) {
        runJS("document.getElementsByClassName('infoLink')[0].style.display='none'")
        runJS("document.getElementsByClassName('surveyItem')[0].children[0].click()")
    }
    
    @IBAction func webFill(_ sender: Any) {
        let elements: [String] = ["toplogo","divRefTab1","divSubmit"]
        let classes: [String] = ["field-label","field-label","field-label"]
        for elementId in elements {
            runJS("document.getElementById('\(elementId)').style.display='none'")
        }
        for elementClass in classes {
            runJS("document.getElementsByClassName('\(elementClass)')[0].style.display='none'")
        }
        runJS("document.getElementsByClassName('ui-radio')[1].click()")
        runJS("document.getElementsByClassName('ui-radio')[0].click()")
        runJS("document.getElementById('fileUpload3').scrollIntoView()")
        runJS("closeNo()")
    }
    
    @IBAction func webSubmit(_ sender: Any) {
        runJS("document.getElementById('ctlNext').click()")
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { result in
                if result != .authorized {
                    return
                }
            }
        }
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAssetSourceTypes = .typeUserLibrary
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }
    }
    
    @IBAction func doneExit(_ sender: Any) {
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        exit(0)
    }
}
