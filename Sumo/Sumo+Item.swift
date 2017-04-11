//
//  Sumo+Item.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/11.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import Foundation
import Photos

extension Sumo {
    
    public class Item: Hashable {
        
        public enum MediaType {
            case image
            case video
        }
        
        public enum Status {
            case none
            case compressed
            case saved
            case ziped
            case completed
        }
        
        let localID: String
        
        var workItem: DispatchWorkItem?
        
        private(set) var status: Status = .none
        
        var asset: PHAsset? {
            didSet {
                guard let asset: PHAsset = asset else {
                    return
                }
                self.name = "\(asset.creationDate!.timeIntervalSince1970)" // TODO: MD5
                switch asset.mediaType {
                case .image: self.mediaType = .image
                case .video: self.mediaType = .video
                default: break
                }
            }
        }
        
        var mediaType: MediaType?
        
        var name: String?
        
        // 動画の場合のみ
        var exportSession: AVAssetExportSession?
        
        var data: Data? {
            didSet {
                self.status = .compressed
            }
        }
        
        var urls: [URL] = [] {
            didSet {
                self.status = .saved
            }
        }
        
        init(localID: String) {
            if localID.isEmpty {
                fatalError("[Sumo] *** error: localID is empty")
            }
            self.localID = localID
        }
        
        public func cancel() {
            debugPrint("[Sumo] cancel :\(self.localID)")
            self.exportSession?.cancelExport()
            self.workItem?.cancel()
            let fileManager: Sumo.FileManager = Sumo.FileManager()
            fileManager.remove(item: self)
        }
        
        public var hashValue: Int {
            return self.localID.hashValue
        }
        
    }
}

public func == (lhs: Sumo.Item, rhs: Sumo.Item) -> Bool {
    return lhs.localID == rhs.localID
}
