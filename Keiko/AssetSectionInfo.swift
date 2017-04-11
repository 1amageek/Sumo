//
//  AssetSectionInfo.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/03.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import Photos

struct SectionInfo {
    let fetchResult: PHFetchResult<PHAsset>
    let assetCollection: PHAssetCollection
    init(fetchResult: PHFetchResult<PHAsset>, assetCollection: PHAssetCollection) {
        self.fetchResult = fetchResult
        self.assetCollection = assetCollection
    }
}
