//
//  ViewController.swift
//  SHTU_SubmitHelper
//
//  Created by wyw on 2022/4/19.
//

import UIKit
import WebKit

class ViewController: UIViewController {
    @IBOutlet var phaseLabels: [UILabel]!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var accLabel: UILabel!
    @IBOutlet weak var configBtn: UIButton!
    var phaseLabelSorted: [UILabel] = []
    
    let initialRequest = URLRequest(url: URL(
        string: "http://wj.shanghaitech.edu.cn/user/qlist.aspx?sysid=159110074")!
    )
    var studentID: String? = UserDefaults.standard.string(forKey: "_SHTU_ID")
    var onWebLoad: (() -> Void) = {}
    var launched = false
    var _phase = -1
    var phase: Int {
        get {_phase}
        set {
            _phase = newValue
            progressView.setProgress(max(0.05, 0.25 * Float(_phase)), animated: true)
            phaseLabelSorted.forEach({$0.textColor = $0.tag == _phase ? .tintColor : .gray})
        }
    }
    let times:[[(Int, Int)]] = [
        [(9, 0), (10, 0)],
        [(13, 30), (14, 30)],
        [(20, 0), (21, 0)]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
        phaseLabelSorted = phaseLabels.sorted(by: {$0.tag < $1.tag})
        phaseLabelSorted.forEach({$0.textColor = .gray})
        progressView.setProgress(0, animated: false)
        configBtn.layer.cornerRadius = 20
        accLabel.text = "Account: \(studentID ?? "not_set")"
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
        for n in 0...2 {
            for t in 0...1 {
                if !UserDefaults.standard.bool(forKey: "_PN_\(n)_\(t)") {
                    addNotification(n, t)
                }
            }
        }
        
        configInit()
    }
    
    func addNotification(_ n: Int, _ t: Int) {
        let content = UNMutableNotificationContent()
        content.title = "抗原检测\(n+1) \(t == 0 ? "已开始" : "即将结束")"
        content.body = "\(times[n][0].0):\(times[n][0].1) - \(times[n][1].0):\(times[n][1].1)"
        content.userInfo = [:]
        content.sound = .default
        var matchingDate = DateComponents()
        matchingDate.hour = times[n][t].1 < 10 ? times[n][t].0 - 1 : times[n][t].0
        matchingDate.minute = times[n][t].1 < 10 ? times[n][t].1 + 50 : times[n][t].1 - 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: matchingDate, repeats: true)
        let requestIdentifier = "com.wyw.tush.n1.begin"
        let request = UNNotificationRequest(
            identifier: requestIdentifier, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) {error in
            if error == nil {
                UserDefaults.standard.set(true, forKey: "_PN_\(n)_\(t)")
            } else {print(error.debugDescription)}
        }
    }
    
    @IBAction func configAction(_ sender: Any) {
        let alert = UIAlertController(
            title: "Initial Config", message: nil,
            preferredStyle: .alert
        )
        alert.addTextField(configurationHandler: {textField in
            textField.keyboardType = .numberPad
            textField.clearButtonMode = .never
            textField.placeholder = "Your SHTU ID"
        })
        alert.addAction(UIAlertAction(
            title: "Done", style: .default, handler: {_ in
                self.studentID = alert.textFields?.first?.text
                UserDefaults.standard.set(self.studentID, forKey: "_SHTU_ID")
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
            print("onload phase", phase)
            switch phase {
            case -1:
                phase = 0
                runJS("document.getElementById('register-user-name').value='\(self.studentID!)';")
                runJS("document.getElementById('btnSubmit').click();")
            case 0:
                phase = 1
                selectLatestForm()
            case 1:
                fillForms()
            case 2:
                submitAction()
            case 3:
                phase = 4
                goHome()
            default: goHome()
            }
        }
        print("xonfig init")
        if studentID == nil {
            configAction(self)
        } else {loginAction()}
    }
    
    func loginAction() {
        print("phase: login")
        accLabel.text = "Account: \(studentID!)"
        webView.load(initialRequest)
    }
    
    func selectLatestForm() {
        print("phase: sel")
        click(on: "/html/body/div[2]/div/div/div/dl[1]/a")
    }
    
    func fillForms() {
        print("phase: fill")
        click(on: "/html/body/form/div[7]/div[3]/fieldset/div[2]/div[2]/div/div")
        click(on: "/html/body/form/div[7]/div[3]/fieldset/div[3]/div[2]/div[1]/div")
        runJS("$(document).scrollTop($(document).height());")
        phase = 2
    }
    
    func submitAction() {
        print("phase: smt")
        phase = 3
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
