//
//  ViewController.swift
//  SHTU_SubmitHelper
//
//  Created by wyw on 2022/4/19.
//

import UIKit
import WebKit

class ViewController: UIViewController {
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var accLabel: UILabel!
    @IBOutlet weak var configBtn: UIButton!
    @IBOutlet weak var tianbiaoBtn: UIButton!
    
    let initialRequest = URLRequest(url: URL(
        string: "http://wj.shanghaitech.edu.cn/user/qlist.aspx?sysid=159110074")!
    )
    var studentID: String? = UserDefaults.standard.string(forKey: "_SHTU_ID")
    var pswd: String? = UserDefaults.standard.string(forKey: "_SHTU_PSWD")
    var onWebLoad: (() -> Void) = {}
    var launched = false
    var _phase = -1
    let times:[[(Int, Int)]] = [
        [(9, 0), (10, 0)],
        [(20, 0), (21, 0)]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
        configBtn.layer.cornerRadius = 20
        tianbiaoBtn.layer.cornerRadius = 20
        accLabel.text = "\(studentID ?? "未登录账号")"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if(launched) {return} else {launched = true}
        UNUserNotificationCenter.current().getNotificationSettings {(setting) in
            if setting.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.badge, .sound, .alert]) {_,_ in
                        DispatchQueue.main.async {
                            self.setup()
                        }
                }
            } else {
                DispatchQueue.main.async {
                    self.setup()
                }
            }
        }
    }
    
    func setup() {
        for n in 0...1 {
            for t in 0...1 {
                if !UserDefaults.standard.bool(forKey: "_nPN_\(n)_\(t)") {
                    addNotification(n, t)
                }
            }
        }
        
        configInit()
    }
    
    func addNotification(_ n: Int, _ t: Int) {
        let content = UNMutableNotificationContent()
        content.title = "抗原检测\(n+1) \(t == 0 ? "已开始" : "即将结束")"
        content.body = "\(times[n][0].0):\(times[n][0].1)0 - \(times[n][1].0):\(times[n][1].1)"
        content.userInfo = [:]
        content.sound = .default
        var matchingDate = DateComponents()
        if t == 0 {
            matchingDate.hour = times[n][t].0
            matchingDate.minute = times[n][t].1
        } else {
            matchingDate.hour = times[n][t].1 < 10 ? times[n][t].0 - 1 : times[n][t].0
            matchingDate.minute = times[n][t].1 < 10 ? times[n][t].1 + 50 : times[n][t].1 - 10
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: matchingDate, repeats: true)
        let requestIdentifier = "com.wyw.tush.n\(n)\(t)"
        let request = UNNotificationRequest(
            identifier: requestIdentifier, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) {error in
            if error == nil {
                UserDefaults.standard.set(true, forKey: "_nPN_\(n)_\(t)")
            } else {print(error.debugDescription)}
        }
    }
    
    @IBAction func fillBtn(_ sender: Any) {
        fillForms()
    }
    
    @IBAction func exitBtn(_ sender: Any) {
        goHome()
    }
    
    @IBAction func configAction(_ sender: Any) {
        let alert = UIAlertController(
            title: "账号设置", message: nil,
            preferredStyle: .alert
        )
        alert.addTextField {textField in
            textField.keyboardType = .numberPad
            textField.clearButtonMode = .never
            textField.placeholder = "你的上科大学号"
            textField.text = self.studentID
        }
        alert.addTextField {textField in
            textField.keyboardType = .numberPad
            textField.clearButtonMode = .never
            textField.placeholder = "身份证后六位"
            textField.text = self.pswd
        }
        alert.addAction(UIAlertAction(
            title: "Done", style: .default, handler: {_ in
                self.studentID = alert.textFields![0].text
                self.pswd = alert.textFields![1].text
                UserDefaults.standard.set(self.studentID, forKey: "_SHTU_ID")
                UserDefaults.standard.set(self.pswd, forKey: "_SHTU_PSWD")
                DispatchQueue.main.async {
                    self.loginAction()
                }
            }
        ))
        present(alert, animated: true)
    }
}

extension ViewController {
    //MARK: Automation Process
    
    func configInit() {
        onWebLoad = {[self] in
            switch _phase {
            case -1:
                _phase = 0
                runJS("document.getElementById('register-user-name').value='\(self.studentID!)';")
                runJS("document.getElementById('register-user-password').value='\(self.pswd!)';")
                runJS("document.getElementById('btnSubmit').click();")
            case 0:
                break
                _phase = 1
                selectLatestForm()
            case 1:
                fillForms()
            case 2:
                break
            case 3:
                break
                goHome()
            default: goHome()
            }
        }
        print("xonfig init")
        if studentID == nil || pswd == nil {
            configAction(self)
        } else {loginAction()}
    }
    
    func loginAction() {
        accLabel.text = "\(studentID!)"
        _phase = -1
        webView.load(initialRequest)
    }
    
    func selectLatestForm() {
        click(on: "/html/body/div[2]/div/div/div/dl[1]/a")
    }
    
    func fillForms() {
        click(on: "/html/body/form/div[7]/div[3]/fieldset/div[2]/div[2]/div/div")
        click(on: "/html/body/form/div[7]/div[3]/fieldset/div[3]/div[2]/div[1]/div")
        if let copiedStr = UIPasteboard.general.string {
            if copiedStr.count < 32 {
                runJS("document.getElementById('q5').value='\(copiedStr)';")
            }
        }
        runJS("$(document).scrollTop($(document).height());")
    }
    
}

extension ViewController {
    //misc helpers
    func goHome() {
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        exit(0)
    }
    
    @inlinable func runJS(_ js: String) {
        webView.evaluateJavaScript(js)
    }
    
    @inlinable func click(on xpath: String) {
        runJS("document.evaluate('\(xpath)',document,null,XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue.click();")
    }
}

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        //
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onWebLoad()
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        let _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {_ in
            DispatchQueue.main.async {
                self.onWebLoad()
            }
        })
    }
}
