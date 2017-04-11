//
//  Sumo.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/11.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import Foundation
import Photos
import NVHTarGzip

/**
 画像・動画の圧縮、コピー、削除を行うクラス
 */

public class Sumo {
    
    public enum SumoError: Error {
        case invalidAsset
        case noData
        case cancelled
        case timeout
        case zipError
    }
    
    public struct Configure {
        struct Image {
            static let targetSize: CGSize = CGSize(width: 2000, height: 2000)
            static let comperesionQuality: CGFloat = 0.8
        }
        struct Video {
            static let targetSize: CGSize = CGSize(width: 2000, height: 2000)
            static let comperesionQuality: CGFloat = 0.6
        }
    }
    
    public static let shared: Sumo = Sumo()
    
    private let sessionQueue: DispatchQueue = DispatchQueue(label: "Sumo.queue")
    
    private(set) var sessions: [Sumo.Session] = []
    
    private let fileManager: Sumo.FileManager = Sumo.FileManager()
    
    private let imageManager: PHImageManager = PHImageManager()
    
    private(set) var currentSession: Sumo.Session?
    
    @discardableResult
    public func startSession(sessionID: String = UUID().uuidString) -> Sumo.Session {
        let session: Session = Session(sessionID: sessionID, queue: sessionQueue)
        if !self.sessions.contains(session) {
            self.sessions.append(session)
        }
        self.currentSession = session
        return session
    }
    
    @discardableResult
    public func startWorflow(_ localIdentifier: String, block: @escaping (Error?) -> Void) -> Item {
        guard let session: Session = self.currentSession else {
            fatalError("[Sumo] *** error: Sumo have not session")
        }
        let item: Item = Item(localID: localIdentifier)
        let workItem: DispatchWorkItem
        workItem = DispatchWorkItem(block: {
            self.pack(item) { (error) in
                if let error = error {
                    block(error)
                    return
                }
                self.save(item) { (error) in
                    if let error = error {
                        block(error)
                        return
                    }
                    
                }
            }
        })
        item.workItem = workItem
        session.add(item: item)
        return item
    }
    
    public func cancel(_ localIdentifier: String) {
        guard let session: Session = self.currentSession else {
            fatalError("[Sumo] *** error: Sumo have not session")
        }
        if let item: Sumo.Item = self.currentSession?.items.filter({ $0.localID == localIdentifier }).first {
            item.cancel()
            session.remove(item: item)
        }
    }
    
    public func reset() {
        guard let session: Session = self.currentSession else {
            fatalError("[Sumo] *** error: Sumo have not session")
        }
        session.reset()
    }
    
    public func stop() {
        guard let session: Session = self.currentSession else {
            fatalError("[Sumo] *** error: Sumo have not session")
        }
        session.stop()
    }
    
    // MARK: Workflow -
    
    // 画像・動画を取得
    private func pack(_ item: Item, block: @escaping (Error?) -> Void) {
        
        guard let workItem: DispatchWorkItem = item.workItem else {
            fatalError("[Sumo] *** error: item have not workItem")
        }
        
        if let asset: PHAsset = PHAsset.fetchAssets(withLocalIdentifiers: [item.localID], options: nil).firstObject {
            if workItem.isCancelled {
                block(SumoError.cancelled)
                return
            }
            item.asset = asset
            switch asset.mediaType {
            case .image:
                // 画像データを取得する
                self.getImageData(item, block: { (data, error) in
                    if let error: Error = error {
                        block(error)
                        return
                    }
                    if workItem.isCancelled {
                        block(SumoError.cancelled)
                        return
                    }
                    if let data: Data = data!.resize(Configure.Image.targetSize, comperesionQuality: Configure.Image.comperesionQuality) {
                        item.data = data
                        debugPrint("[Sumo] get image data")
                        block(nil)
                    }
                })
            case .video:
                // 動画データを取得する
                self.getVideoData(item, block: { (thumbnail, error) in
                    if let error: Error = error {
                        block(error)
                        return
                    }
                    if workItem.isCancelled {
                        block(SumoError.cancelled)
                        return
                    }
                    // Thumbnailをリサイズ
                    if let data: Data = thumbnail!.resize(Configure.Video.targetSize, comperesionQuality: Configure.Video.comperesionQuality) {
                        item.data = data
                        debugPrint("[Sumo] get video thumbnail data")
                        block(nil)
                    }
                })
            default: break
            }
        }
    }
    
    /// ライブラリから画像を取得する
    private func getImageData(_ item: Item, block: @escaping (Data?, Error?) -> Void) {
        
        guard let asset: PHAsset = item.asset else {
            debugPrint("[Sumo] Item has not asset.")
            block(nil, SumoError.invalidAsset)
            return
        }
        
        let options: PHImageRequestOptions = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        self.imageManager.requestImageData(for: asset, options: options) { (data, dataUTI, orientation, info) in
            guard let data: Data = data else {
                block(nil, SumoError.noData)
                return
            }
            block(data, nil)
        }
    }
    
    /// ライブラリから動画を取得する
    private func getVideoData(_ item: Item, block: @escaping (Data?, Error?) -> Void) {
        
        guard let asset: PHAsset = item.asset else {
            debugPrint("[Sumo] Item has not asset.")
            block(nil, SumoError.invalidAsset)
            return
        }
        
        self.getImageData(item) { (thumbnail, error) in
            if let error: Error = error {
                block(thumbnail, error)
                return
            }
            if item.workItem?.isCancelled ?? false {
                block(thumbnail, SumoError.cancelled)
                return
            }
            
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.deliveryMode = .mediumQualityFormat
            options.isNetworkAccessAllowed = false
            options.version = .original
            
            // 同期処理に変換
            let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
            self.imageManager.requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPreset960x540) { (exportSession, info) in
                defer {
                    semaphore.signal()
                }
                if item.workItem?.isCancelled ?? false {
                    block(thumbnail, SumoError.cancelled)
                    return
                }
                guard let exportSession: AVAssetExportSession = exportSession else {
                    block(thumbnail, SumoError.invalidAsset)
                    return
                }
                item.exportSession = exportSession
                block(thumbnail, nil)
            }
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
    
    // /temp/Sumo/sessionID/へDataを保存
    private func save(_ item: Item, block: @escaping (Error?) -> Void) {
        guard let workItem: DispatchWorkItem = item.workItem else {
            fatalError("[Sumo] *** error: item have not workItem")
        }
        if workItem.isCancelled {
            block(SumoError.cancelled)
            return
        }
        debugPrint("[Sumo] save data")
        self.fileManager.save(item, session: self.currentSession!, block: block)
    }
    
    // SessionのWorkflowが完了したらアップロードを開始する
    public func upload(session: Sumo.Session, block: @escaping (Error?) -> Void) {
        
    }
    
    public func zip(block: @escaping ((URL?, Error?) -> Void)) {
        guard let session: Session = self.currentSession else {
            fatalError("[Sumo] *** error: Sumo have not session")
        }
        DispatchQueue.global(qos: .background).async {
            session.workGroup.notify(queue: .main) {
                
                if session.isCanceled {
                    block(nil, SumoError.cancelled)
                    return
                }
                
                let tarURL: URL = session.url!.appendingPathExtension("tar")
                NVHTarGzip.sharedInstance().tarFile(atPath: session.url!.path, toPath: tarURL.path, completion: { error in
                    if let _ = error {
                        block(nil, SumoError.zipError)
                        return
                    }
                    debugPrint("[Sumo] zip completed.")
                    session.packageURL = tarURL
                    block(tarURL, nil)
                })
                
            }
            switch session.workGroup.wait(timeout: .distantFuture) {
            case .success: break
            case .timedOut: block(nil, SumoError.timeout)
            }
        }
    }
    
    private func transmit(block: (Error?) -> Void) {
        
    }
    
}
