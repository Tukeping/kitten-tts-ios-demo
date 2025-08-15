//
//  Keys.swift
//  kitten-tts-ios-demo
//
//  Created by FredTu on 2025-08-15
//

import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

func z_print(_ items: Any...,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
    #if DEBUG
        let  fileName = (file as NSString).lastPathComponent
        debugPrint("\(fileName):\(line) \(function) | ", items)
    #endif
}

var z_width: CGFloat {
    return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.screen.bounds.size.width ?? 375
}

var z_height: CGFloat {
    return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.screen.bounds.size.height ?? 667
}

func adaptive(_ phone: CGFloat, pad: CGFloat? = nil) -> CGFloat {
    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
    return isIPad ? (pad ?? phone * 1.5) : phone
}

//Colors
let c_C2F94D       = UIColor(hex: 0xC2F94D)
let c_95E80D      = UIColor(hex: 0x95E80D)

let c_F4EDFF      = UIColor(hex: 0xF4EDFF)
let c_C488FF       = UIColor(hex: 0xC488FF)

let c_94F658       = UIColor(hex: 0x94F658)
let c_FDB022       = UIColor(hex: 0xFDB022)
let c_F6516F       = UIColor(hex: 0xF6516F)

let c_D1D5DB    = UIColor(hex: 0xD1D5DB)
let c_9CA3AF    = UIColor(hex: 0x9CA3AF)
let c_6B7280    = UIColor(hex: 0x6B7280)
let c_475569    = UIColor(hex: 0x475569)
let c_454F52      = UIColor(hex: 0x454F52)
let c_1E293B    = UIColor(hex: 0x1E293B)
let c_122022       = UIColor(hex: 0x122022)

let c_F4F8FC       = UIColor(hex: 0xF4F8FC)
let c_E9EDF5       = UIColor(hex: 0xE9EDF5)
let c_EFF2F4       = UIColor(hex: 0xEFF2F4)
let c_64748B     = UIColor(hex: 0x64748B)

extension UIFont {
    static var adaptiveTitle: UIFont {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return .systemFont(ofSize: isIPad ? 32 : 24, weight: .bold)
    }
    
    static var adaptiveSubtitle: UIFont {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return .systemFont(ofSize: isIPad ? 20 : 16, weight: .medium)
    }
    
    static var adaptiveBody: UIFont {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return .systemFont(ofSize: isIPad ? 18 : 14)
    }
}

extension UIView {
    func adaptivePadding() -> CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad ? 32 : 20
    }
    
    func adaptiveSpacing() -> CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad ? 24 : 16
    }
    
    func adaptiveCornerRadius() -> CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad ? 16 : 12
    }
}

struct Singleton {
    struct DeviceConfig {
        static var buttonHeight: CGFloat {
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            return isIPad ? 60 : 48
        }
    }
}
