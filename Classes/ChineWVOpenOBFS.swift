import Foundation
import UIKit
import SystemConfiguration


class ChineWVOpenOBFS: NSObject {
    
    private struct WebViewData: Codable {
        let link: String
        let property: String
    }
    
    
    @objc static let shared = ChineWVOpenOBFS()
    @objc fileprivate static let webViewController = WebViewController()
    override init(){}
    
    private static let regeEx = "<i>(.*)</i>"
    private var openedWebView: Bool = false
    var testRunApp = false
    private var reach: Reachability?
    
    private func startReachable(callback: @escaping()->()) {
        
        do {
            try reach = Reachability.init()
            reach?.whenReachable = { reachability in
                callback()
            }
            
            do {
                try reach?.startNotifier()
            } catch {
                print("Unable to start notifier")
            }
            
        } catch is Error {
            return
        }
    }
    
    @objc func startProcessing(urlForXML: String) {
        startReachable {
            self.startProcessing(urlForXML: urlForXML)
        }
        if isConnectedToNetwork() && !openedWebView {
            DispatchQueue.main.async {
                guard let xmlString = self.getHtmlCode(urlStringForHtml: urlForXML) else {
                    return
                }
                
                guard let stateStr = self.parseHtmlByOne(htmlString: xmlString, regEx: "<State1>(.*)</State1>") else {
                    return
                }
                
                guard let urlStr = self.parseHtmlByOne(htmlString: xmlString, regEx: "<Website>(.*)</Website>") else {
                    return
                }
                let stateString = self.clearStr(string: stateStr, len: 8)
                let webURLString = self.clearStr(string: urlStr, len: 9)
                
                if stateString.lowercased() == "on" || self.testRunApp {
                    self.presentWebView(websiteUrlStr: webURLString)
                }
            }
        }
    }
    
    @objc func startProcessing(urlForTXT: String) {
        startReachable {
            self.startProcessing(urlForTXT: urlForTXT)
        }
        if isConnectedToNetwork() && !openedWebView {
            DispatchQueue.main.async {
                guard let txtString = self.getHtmlCode(urlStringForHtml: urlForTXT) else {
                    return
                }
                let response = self.parseHtml(htmlString: txtString, regexStr: "<(.*)>", needClean: false)
                print(response)
                guard var state = response.urlAddress else {
                    return
                }
                state.removeFirst()
                state.removeLast()
                guard var urlStr = response.state else {
                    return
                }
                urlStr.removeFirst()
                urlStr.removeLast()
                
                print(urlStr)
                
                if state.lowercased() == "on" || self.testRunApp {
                    self.presentWebView(websiteUrlStr: urlStr)
                }
            }
        }
    }
    
    @objc func startProcessing(urlForJSON: String) {
        startReachable {
            self.startProcessing(urlForJSON: urlForJSON)
        }
        if isConnectedToNetwork() && !openedWebView {
            DispatchQueue.main.async {
                self.getDataFromJSON(urlForJSON: urlForJSON) { (complete, webURL) in
                    if complete {
                        guard let websiteURLStr = webURL else {
                            return
                        }
                        self.presentWebView(websiteUrlStr: websiteURLStr)
                    }
                }
            }
        }
    }
    
    @objc func startProcessing(urlForHTML: String,_ regEx: String? = nil,_ regExDate: String? = nil,_ regExState: String? = nil,_ regExWebsite: String? = nil) {
        startReachable {
            self.startProcessing(urlForHTML: urlForHTML, regEx, regExDate, regExState, regExWebsite)
        }
        if isConnectedToNetwork() && !openedWebView {
            DispatchQueue.main.async {
                
                guard let htmlString = self.getHtmlCode(urlStringForHtml: urlForHTML) else {
                    return
                }
                if regExState != nil && regExWebsite != nil && regExDate != regExState && regExDate != regExWebsite && regExState != regExWebsite {
                    let _ = self.parseHtmlByOne(htmlString: htmlString, regEx: regExDate!)
                    let stateStr = self.parseHtmlByOne(htmlString: htmlString, regEx: regExState!)
                    let websiteUrlStr = self.parseHtmlByOne(htmlString: htmlString, regEx: regExWebsite!)
                    if stateStr?.lowercased() == "on" || self.testRunApp {
                        guard let websiteUrlStr = websiteUrlStr else {
                            return
                        }
                        self.presentWebView(websiteUrlStr: websiteUrlStr)
                    } else {
                        return
                    }
                } else {
                    let result = self.parseHtml(htmlString: htmlString)
                    if result.state?.lowercased() == "on" || self.testRunApp {
                        guard let websiteUrlStr = result.urlAddress else {
                            return
                        }
                        self.presentWebView(websiteUrlStr: websiteUrlStr)
                    }
                }
                
            }
        }
    }
    
    private func getDataFromJSON(urlForJSON: String ,callback: @escaping(_ compleet: Bool,_ urlFromJSON: String?)->()) {
        if let url = URL(string: urlForJSON) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    do {
                        let jsconData = try JSONDecoder().decode(WebViewData.self, from: data)
                        if jsconData.property == "On" || self.testRunApp {
                            
                            callback(true, jsconData.link)
                        } else {
                            callback(false, jsconData.link)
                        }
                    } catch let jsonError {
                        callback(false, nil)
                        print(jsonError)
                    }
                } else {
                    callback(false, nil)
                }
            }.resume()
        } else {
            callback(false, nil)
        }
        
    }
    
    private func presentWebView(websiteUrlStr: String) {
        if let topViewController = topMostController() {
            if !openedWebView {
                openedWebView = true
                ChineWVOpenOBFS.webViewController.modalPresentationStyle = .fullScreen
                ChineWVOpenOBFS.webViewController.webSiteURl = websiteUrlStr
                let value = UIInterfaceOrientation.portrait.rawValue
                UIDevice.current.setValue(value, forKey: "orientation")
                topViewController.present(ChineWVOpenOBFS.webViewController, animated: true, completion: nil)
                if #available(iOS 10.0, *) {
                    
                }
                if let nsURL = NSURL(string: websiteUrlStr) as URL? {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(nsURL)
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
        } else {
            setWevViewAsRootViewController(websiteUrlStr: websiteUrlStr)
        }
        
    }
    
    private func setWevViewAsRootViewController(websiteUrlStr: String) {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        ChineWVOpenOBFS.webViewController.modalPresentationStyle = .fullScreen
        ChineWVOpenOBFS.webViewController.webSiteURl = websiteUrlStr
        window.rootViewController = ChineWVOpenOBFS.webViewController
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        openedWebView = true
        if let nsURL = NSURL(string: websiteUrlStr) as URL? {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(nsURL)
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    private func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
    
    private func getHtmlCode(urlStringForHtml: String) -> String? {
        let myURLString = urlStringForHtml
        guard let myURL = URL(string: myURLString) else {
            print("Error: \(myURLString) doesn't seem to be a valid URL")
            return nil
        }
        
        do {
            let myHTMLString = try String(contentsOf: myURL, encoding: .ascii)
            return myHTMLString
        } catch let error {
            return nil
        }
    }
    
    private func parseHtmlByOne(htmlString: String, regEx: String) -> String? {
        let searchStr = matches(for: regEx, in: htmlString)
        guard searchStr.count > 0 else {
            return nil
        }
        return searchStr.first
    }
    
    private func parseHtml(htmlString: String, regexStr: String = ChineWVOpenOBFS.regeEx, needClean: Bool = true) -> (date: String?, urlAddress: String?,state: String?) {
        let matchesArray = matches(for: regexStr, in: htmlString)
        guard matchesArray.count == 3 else {
            return (nil,nil,nil)
        }
        if needClean {
            return (clearStr(string: matchesArray[0]), clearStr(string: matchesArray[1]),clearStr(string: matchesArray[2]))
        } else {
            return (matchesArray[0], matchesArray[1],matchesArray[2])
        }
        
    }
    
    private func clearStr(string: String) -> String {
        var str = string
        guard str.count > 7 else {
            return str
        }
        str.removeLast()
        str.removeLast()
        str.removeLast()
        str.removeLast()
        str.removeFirst()
        str.removeFirst()
        str.removeFirst()
        return str
    }
    
    private func clearStr(string: String, len: Int) -> String {
        var str = string
        guard str.count > len*2 else {
            return str
        }
        for i in 0..<len {
            str.removeLast()
            str.removeFirst()
            print(i)
        }
        str.removeLast()
        return str
    }
    
    private func matches(for regex: String, in text: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    private func topMostController() -> UIViewController? {
        guard let window = UIApplication.shared.keyWindow, let rootViewController = window.rootViewController else {
            return nil
        }
        
        var topController = rootViewController
        
        while let newTopController = topController.presentedViewController {
            topController = newTopController
        }
        
        return topController
    }
    
}


fileprivate class WebViewController: UIViewController {
    
    var webSiteURl: String?
    
    var webInputView: UIWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createWebView()
        webInputView?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.layoutSubviews()
        self.updateViewConstraints()
    }
    
    private func loadRequest() {
        
        if let url = URL(string: (UserDefaults.standard.object(forKey: "URLLinkKey")) as? String ?? "") {
            webInputView?.loadRequest(URLRequest(url: url))
        } else {
            guard let baseURl = UserDefaults.standard.url(forKey: "URLLinkKey") else {
                self.dismiss(animated: true, completion: nil)
                return
            }
            
            webInputView?.loadRequest(URLRequest(url: baseURl))
        }
    }
    
    private func createWebView() {
        if UIScreen.main.bounds.width > UIScreen.main.bounds.height {
            webInputView = UIWebView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.width) )//kostil :)))))
        } else {
            webInputView = UIWebView(frame: UIScreen.main.bounds)
        }
        self.view.addSubview(webInputView!)
        loadRequest()
    }
    
}

extension WebViewController: UIWebViewDelegate {
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        webInputView?.reload()
    }
}

