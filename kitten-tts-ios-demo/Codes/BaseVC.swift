//
//  BaseVC.swift
//  kitten-tts-ios-demo
//
//  Created by FredTu on 2025-08-15
//

import UIKit

class BaseVC: UIViewController {
    
    var closeBackGesture = false
    
    var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    func adaptive(_ phone: CGFloat, pad: CGFloat? = nil) -> CGFloat {
        return isIPad ? (pad ?? phone * 1.5) : phone
    }
    
    var adaptivePadding: CGFloat {
        return isIPad ? 32 : 20
    }
    
    var adaptiveSpacing: CGFloat {
        return isIPad ? 24 : 16
    }
    
    var maxContentWidth: CGFloat {
        let screenWidth = view.window?.windowScene?.screen.bounds.width ?? z_width
        return isIPad ? min(screenWidth * 0.7, 768) : screenWidth
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = c_F4F8FC
        setupBack()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if closeBackGesture {
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if closeBackGesture {
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
    
    func setupBack() {
        let name = closeBackGesture ? "xmark" : "chevron.left"
        let backButton = UIBarButtonItem(image: UIImage(systemName: name), style: .plain, target: self, action: #selector(clickBack))
        backButton.tintColor = c_122022
        navigationItem.leftBarButtonItem = backButton
        
        navigationController?.interactivePopGestureRecognizer?.delegate = self as? UIGestureRecognizerDelegate
    }
    
    @objc func clickBack() {
        navigationController?.popViewController(animated: true)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}
