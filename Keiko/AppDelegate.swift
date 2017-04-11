//
//  AppDelegate.swift
//  Keiko
//
//  Created by 1amageek on 2017/04/11.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UINavigationController(rootViewController: MediaPickerController())
        self.window?.makeKeyAndVisible()
        return true
    }
    
}

