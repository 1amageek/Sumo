//
//  NSFileManager+NVHFileSize.m
//  Pods
//
//  Created by Niels van Hoorn on 03/07/15.
//
//

#import "NSFileManager+NVHFileSize.h"

@implementation NSFileManager (NVHFileSize)

- (unsigned long long)fileSizeOfItemAtPath:(NSString *)path {
    NSError *error = nil;
    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (error != nil)
    {
        return 0;
    }
    return [attributes fileSize];
}

@end
