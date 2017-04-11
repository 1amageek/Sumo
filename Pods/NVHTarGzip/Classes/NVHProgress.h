//
//  NVHProgress.h
//  Pods
//
//  Created by Niels van Hoorn on 03/07/15.
//
//

#import <Foundation/Foundation.h>

@interface NVHProgress : NSObject

- (void)setVirtualTotalUnitCount:(int64_t)virtualTotalUnitCount;
- (void)setVirtualCompletedUnitCount:(int64_t)virtualUnitCount;
- (void)setVirtualCompletedUnitCountToTotal;

@end
