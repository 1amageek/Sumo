//
//  Data+.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/11.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import UIKit
import ImageIO

extension Data {
    func resize(_ size: CGSize, comperesionQuality: CGFloat = 0.7) -> Data? {
        let cfData: CFData = CFDataCreate(kCFAllocatorDefault, (self as NSData).bytes.bindMemory(to: UInt8.self, capacity: self.count), self.count)
        if let imageSource: CGImageSource = CGImageSourceCreateWithData(cfData, nil) {
            let options: [NSString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: Swift.max(size.width, size.height),
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            let scaledImage: UIImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?).flatMap { UIImage(cgImage: $0) }!
            return UIImageJPEGRepresentation(scaledImage, comperesionQuality)
        }
        return nil
    }
}
