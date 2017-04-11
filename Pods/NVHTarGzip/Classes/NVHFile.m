//
//  NVHFile.m
//  Pods
//
//  Created by Niels van Hoorn on 26/03/14.
//
//

#import "NVHFile.h"
#import "NSFileManager+NVHFileSize.h"
#import "NVHProgress.h"


@interface NVHFile ()

@property (nonatomic) NVHProgress *progress;
@property (nonatomic, strong) NSString *filePath;

@end


@implementation NVHFile

- (instancetype)initWithPath:(NSString *)filePath {
    self = [super init];
    if (self) {
        self.filePath = filePath;
    }
    return self;
}

- (unsigned long long)fileSize {
    return [[NSFileManager defaultManager] fileSizeOfItemAtPath:self.filePath];
}

- (void)setupProgress
{
    self.progress = [[NVHProgress alloc] init];
}

- (void)updateProgressVirtualTotalUnitCount:(int64_t)virtualUnitCount
{
    [self.progress setVirtualTotalUnitCount:virtualUnitCount];
}

- (void)updateProgressVirtualCompletedUnitCount:(int64_t)virtualUnitCount
{
    [self.progress setVirtualCompletedUnitCount:virtualUnitCount];
}

- (void)updateProgressVirtualTotalUnitCountWithFileSize
{
    [self updateProgressVirtualTotalUnitCount:self.fileSize];
}

- (void)updateProgressVirtualCompletedUnitCountWithTotal
{
    [self.progress setVirtualCompletedUnitCountToTotal];
}

@end
