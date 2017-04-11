//
//  NVHProgress.m
//  Pods
//
//  Created by Niels van Hoorn on 03/07/15.
//
//

#import "NVHProgress.h"

/** Using a small maximum total unit count instead of using self.fileSize
 * directly is recommended to let it work nicely with parent progress objects
 * because of this bug rdar://16444353 (http://openradar.appspot.com/radar?id=5775860476936192)
 *
 * Default is 100;
 */
const int64_t NVHProgressMaxTotalUnitCount = 100;

@interface NVHProgress ()

@property (nonatomic) NSProgress *progress;
@property (nonatomic, assign) double countFraction;

@end

@implementation NVHProgress

// Designated initializer;
- (instancetype)init
{
    self = [super init];
    if (!self) { return nil; }
    
    self.progress = [NSProgress progressWithTotalUnitCount:NVHProgressMaxTotalUnitCount];
    self.progress.cancellable = NO;
    self.progress.pausable = NO;
    
    return self;
}

- (void)setVirtualTotalUnitCount:(int64_t)virtualTotalUnitCount
{
    self.countFraction = (double)NVHProgressMaxTotalUnitCount / (double)virtualTotalUnitCount;
}

- (void)setVirtualCompletedUnitCount:(int64_t)virtualUnitCount
{
    self.progress.completedUnitCount = roundf( self.countFraction * virtualUnitCount );
}

- (void)setVirtualCompletedUnitCountToTotal
{
    self.progress.completedUnitCount = NVHProgressMaxTotalUnitCount;
}

@end
