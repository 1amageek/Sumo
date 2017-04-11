//
//  MediaPickerProtocol.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/03.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import Foundation
import Photos

protocol MediaPickerProtocol {
 
    var countOfPhotos: Int { get set }
    var countOfVideos: Int { get set }
    
    var hasReachedLimitOfPhotos: Bool { get }
    var hasReachedLimitOfVideos: Bool { get }
    
    var limitOfPhotos: Int { get }
    var limitOfVidoes: Int { get }
    
}

extension MediaPickerProtocol {

    var hasReachedLimitOfPhotos: Bool { return limitOfPhotos <= countOfPhotos }
    var hasReachedLimitOfVideos: Bool { return limitOfVidoes <= countOfVideos }
    
    var limitOfPhotos: Int {
        return 50
    }
    
    var limitOfVidoes: Int {
        return 3
    }
    
    mutating func selectWithAsset(asset: PHAsset) {
        switch asset.mediaType {
        case .image: countOfPhotos += 1
        case .video: countOfVideos += 1
        default: break
        }
    }
    
    mutating func deSelectWithAsset(asset: PHAsset) {
        switch asset.mediaType {
        case .image: countOfPhotos -= 1
        case .video: countOfVideos -= 1
        default: break
        }
    }
}
