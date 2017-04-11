//
//  Sumo+FileManager.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/11.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import Foundation
import Photos

extension Sumo {
    
    public class FileManager {
        
        private let dirName: String = "Sumo"
        
        let fileManager: Foundation.FileManager = Foundation.FileManager.default
        
        var baseURL: URL {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(self.dirName, isDirectory: true)
        }
        
        func save(_ item: Sumo.Item, session: Sumo.Session, block: ((Error?) -> Void)) {
            
            // SessionIDのURLを作成
            let dirURL: URL = baseURL.appendingPathComponent(session.sessionID, isDirectory: true)
            
            session.url = dirURL
            
            // 保存先のDirを作成
            do {
                try self.fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                debugPrint(error)
                block(error)
                return
            }
            
            switch item.mediaType! {
            case .image:
                
                let url: URL = dirURL.appendingPathComponent(item.name!, isDirectory: false).appendingPathExtension("jpg")
                do {
                    try self.saveImage(url: url, data: item.data!)
                    item.urls.append(url)
                    debugPrint("[Sumo FileManager] Save Image: \(url)")
                } catch let error {
                    debugPrint(error)
                    block(error)
                    return
                }
                
            case .video:
                
                // thumbnail
                do {
                    let url: URL = dirURL.appendingPathComponent(item.name!, isDirectory: false).appendingPathExtension("jpg")
                    try self.saveImage(url: url, data: item.data!)
                    item.urls.append(url)
                    debugPrint("[Sumo FileManager] Save Thumbnail: \(url)")
                } catch let error {
                    debugPrint(error)
                    block(error)
                    return
                }
                
                // video
                do {
                    let url: URL = dirURL.appendingPathComponent(item.name!, isDirectory: false).appendingPathExtension("mp4")
                    try self.saveVideo(url: url, exportSession: item.exportSession!)
                    item.urls.append(url)
                    debugPrint("[Sumo FileManager] Save Video: \(url)")
                } catch let error {
                    debugPrint(error)
                    block(error)
                    return
                }
            }
            
            block(nil)
        }
        
        private func saveImage(url: URL, data: Data) throws {
            // Fileが存在した場合は削除する
            if self.fileManager.fileExists(atPath: url.path) {
                do {
                    try self.fileManager.removeItem(atPath: url.path)
                } catch let error {
                    debugPrint(error)
                    throw error
                }
            }
            
            // Dataを保存する
            do {
                try data.write(to: url, options: .atomicWrite)
            } catch let error {
                debugPrint(error)
                throw error
            }
        }
        
        private func saveVideo(url: URL, exportSession: AVAssetExportSession) throws {
            let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
            var error: SumoError?
            exportSession.outputURL = url
            exportSession.outputFileType = AVFileTypeMPEG4
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    semaphore.signal()
                case .failed:
                    error = SumoError.noData
                    semaphore.signal()
                case .cancelled:
                    error = SumoError.cancelled
                    semaphore.signal()
                default: break
                }
            }
            _ = semaphore.wait(timeout: .distantFuture)
            
            if let error = error {
                throw error
            }
        }
        
        
        func remove(item: Sumo.Item) {
            item.urls.forEach { (url) in
                // ファイルが存在すれば削除する
                if self.fileManager.fileExists(atPath: url.path) {
                    debugPrint("[Sumo FileManager] remove path: \(url.path)")
                    _ = try? self.fileManager.removeItem(atPath: url.path)
                }
            }
        }
        
        func remove(session: Sumo.Session) {
            guard let path: String = session.url?.path else {
                return
            }
            if self.fileManager.fileExists(atPath: path) {
                _ = try? self.fileManager.removeItem(atPath: path)
            }
            
            guard let packageURL: String = session.packageURL?.path else {
                return
            }
            if self.fileManager.fileExists(atPath: packageURL) {
                _ = try? self.fileManager.removeItem(atPath: packageURL)
            }
        }
        
    }
    
}

