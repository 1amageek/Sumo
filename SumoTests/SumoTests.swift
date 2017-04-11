//
//  SumoTests.swift
//  SumoTests
//
//  Created by 1amageek on 2017/04/11.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import XCTest
@testable import Sumo
import Quick
import Nimble
import Photos

class SumoSpec: QuickSpec {

    override func spec() {
        describe("Copy") {
            it("Start session") {
                let session: Sumo.Session = Sumo.shared.startSession(sessionID: "session_id")
                expect(session.sessionID).to(equal("session_id"))
            }
            
            it("Start workflow") {
                // UnitTestでは無理か。。
                PHPhotoLibrary.requestAuthorization({ (status) in
                    DispatchQueue.main.async {
                        print(status)
                        let bundle: Bundle = Bundle(for: SumoSpec.self)
                        let path: String = bundle.path(forResource: "siko", ofType: "jpg")!
                        let image: UIImage = UIImage(contentsOfFile: path)!
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        let fetchResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(with: nil)
                        let asset: PHAsset = fetchResult.firstObject!
                        Sumo.shared.startWorflow(asset.localIdentifier, block: { (error) in
                            expect(Sumo.shared.currentSession?.items.count).to(equal(1))
                        })
                    }
                })
                waitUntil(timeout: 1, action: {_ in })
            }
        }
    }
    
}
