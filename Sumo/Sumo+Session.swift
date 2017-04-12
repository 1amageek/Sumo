//
//  Sumo+Session.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/11.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import Foundation

extension Sumo {
    
    public class Session: Hashable {
        
        public struct Options {
            var imageTargetSize: CGSize = CGSize(width: 2000, height: 2000)
            var imageComperesionQuality: CGFloat = 0.8
            var videoTargetSize: CGSize = CGSize(width: 2000, height: 2000)
            var videoComperesionQuality: CGFloat = 0.8
        }
        
        public let sessionID: String
        
        public let options: Options
        
        public let queue: DispatchQueue
        
        public let workGroup: DispatchGroup = DispatchGroup()
        
        public var url: URL?
        
        
        // zip(tar)化されたファイルのURL
        public var packageURL: URL?
        
        private(set) var items: [Sumo.Item] = []
        
        private(set) var isCanceled: Bool = false
        
        init(sessionID: String, options: Options, queue: DispatchQueue) {
            self.sessionID = sessionID
            self.options = options
            self.queue = queue
        }
        
        public var hashValue: Int {
            return self.sessionID.hash
        }
        
        /// アイテムを追加する
        public func add(item: Sumo.Item) {
            // すでにキャンセルされたSessionは何もしない
            if self.isCanceled {
                return
            }
            self.items.append(item)
            self.queue.async(group: workGroup, execute: item.workItem!)
        }
        
        /// アイテムを削除する
        public func remove(item: Sumo.Item) {
            if let index: Int = self.items.index(of: item) {
                self.items.remove(at: index)
            }
        }
        
        /// セッションを保持したままItemを全て削除する
        public func reset() {
            self.isCanceled = true
            self.items.forEach { (item) in
                item.cancel()
            }
            self.items = []
            self.isCanceled = false
        }
        
        /// セッションを終了させる
        public func stop() {
            self.isCanceled = true
            self.items.forEach { (item) in
                item.cancel()
            }
            self.items = []
            let fileManager: Sumo.FileManager = Sumo.FileManager()
            fileManager.remove(session: self)
        }
        
    }
    
}

public func == (lhs: Sumo.Session, rhs: Sumo.Session) -> Bool {
    return lhs.sessionID == rhs.sessionID
}

