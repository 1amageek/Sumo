//
//  NVHTarGzip.m
//  Pods
//
//  Created by Niels van Hoorn on 26/03/14.
//
//

#import "NVHTarGzip.h"
#import "NVHGzipFile.h"
#import "NVHTarFile.h"


@interface NVHTarGzip()

@end


@implementation NVHTarGzip

+ (NVHTarGzip *)sharedInstance {
    static dispatch_once_t onceToken;
    static NVHTarGzip *tarGzip;
    dispatch_once(&onceToken, ^{
        tarGzip = [NVHTarGzip new];
    });
    return tarGzip;
}

- (BOOL)unTarFileAtPath:(NSString *)sourcePath
                 toPath:(NSString *)destinationPath
                  error:(NSError **)error {
    NVHTarFile* tarFile = [[NVHTarFile alloc] initWithPath:sourcePath];
    return [tarFile createFilesAndDirectoriesAtPath:destinationPath error:error];
}

- (BOOL)unGzipFileAtPath:(NSString *)sourcePath
                  toPath:(NSString *)destinationPath
                   error:(NSError **)error {
    NVHGzipFile* gzipFile = [[NVHGzipFile alloc] initWithPath:sourcePath];
    return [gzipFile inflateToPath:destinationPath error:error];
}

- (BOOL)unTarGzipFileAtPath:(NSString *)sourcePath
                     toPath:(NSString *)destinationPath
                      error:(NSError **)error {
    NSString *temporaryPath = [self temporaryFilePathForPath:sourcePath];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    [self unGzipFileAtPath:sourcePath toPath:temporaryPath error:error];
    [progress resignCurrent];
    if (*error != nil) {
        return NO;
    }
    [progress becomeCurrentWithPendingUnitCount:1];
    [self unTarFileAtPath:temporaryPath toPath:destinationPath error:error];
    NSError *removeTemporaryFileError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:&removeTemporaryFileError];
    if (*error != nil) {
        return NO;
    }
    if (removeTemporaryFileError != nil) {
        *error = removeTemporaryFileError;
        return NO;
    }
    [progress resignCurrent];
    return YES;
}

- (BOOL)tarFileAtPath:(NSString *)sourcePath
               toPath:(NSString *)destinationPath
                error:(NSError **)error {
    NVHTarFile* tarFile = [[NVHTarFile alloc] initWithPath:destinationPath];
    return [tarFile packFilesAndDirectoriesAtPath:sourcePath error:error];
}

- (BOOL)gzipFileAtPath:(NSString *)sourcePath
                toPath:(NSString *)destinationPath
                 error:(NSError **)error {
    NVHGzipFile* gzipFile = [[NVHGzipFile alloc] initWithPath:destinationPath];
    return [gzipFile deflateFromPath:sourcePath error:error];
}

- (BOOL)tarGzipFileAtPath:(NSString *)sourcePath
                   toPath:(NSString *)destinationPath
                    error:(NSError **)error {
    NSString *temporaryPath = [self temporaryFilePathForPath:sourcePath];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    [self tarFileAtPath:sourcePath toPath:temporaryPath error:error];
    [progress resignCurrent];
    if (*error != nil) {
        return NO;
    }
    [progress becomeCurrentWithPendingUnitCount:1];
    [self gzipFileAtPath:temporaryPath toPath:destinationPath error:error];
    NSError* removeCacheError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:&removeCacheError];
    if (*error != nil) {
        return NO;
    }
    if (removeCacheError != nil) {
        *error = removeCacheError;
        return NO;
    }
    [progress resignCurrent];
    return YES;
}

- (void)unTarFileAtPath:(NSString *)sourcePath
                 toPath:(NSString *)destinationPath
             completion:(void(^)(NSError *))completion {
    NVHTarFile* tarFile = [[NVHTarFile alloc] initWithPath:sourcePath];
    [tarFile createFilesAndDirectoriesAtPath:destinationPath completion:completion];
}

- (void)unGzipFileAtPath:(NSString *)sourcePath
                  toPath:(NSString *)destinationPath
              completion:(void(^)(NSError *))completion {
    NVHGzipFile* gzipFile = [[NVHGzipFile alloc] initWithPath:sourcePath];
    [gzipFile inflateToPath:destinationPath completion:completion];
}

- (void)unTarGzipFileAtPath:(NSString*)sourcePath
                     toPath:(NSString*)destinationPath
                 completion:(void(^)(NSError *))completion {
    NSString *temporaryPath = [self temporaryFilePathForPath:sourcePath];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    [self unGzipFileAtPath:sourcePath toPath:temporaryPath completion:^(NSError *gzipError) {
        [progress resignCurrent];
        if (gzipError != nil) {
            completion(gzipError);
            return;
        }
        [progress becomeCurrentWithPendingUnitCount:1];
        [self unTarFileAtPath:temporaryPath toPath:destinationPath completion:^(NSError *tarError) {
            NSError* error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:&error];
            [progress resignCurrent];
            if (tarError != nil) {
                error = tarError;
            }
            completion(error);
        }];
    }];
}

- (void)tarFileAtPath:(NSString *)sourcePath
               toPath:(NSString *)destinationPath
           completion:(void(^)(NSError *))completion {
    NVHTarFile *tarFile = [[NVHTarFile alloc] initWithPath:destinationPath];
    [tarFile packFilesAndDirectoriesAtPath:sourcePath completion:completion];
}

- (void)gzipFileAtPath:(NSString *)sourcePath
                toPath:(NSString *)destinationPath
            completion:(void(^)(NSError *))completion {
    NVHGzipFile *gzipFile = [[NVHGzipFile alloc] initWithPath:destinationPath];
    [gzipFile deflateFromPath:sourcePath completion:completion];
}

- (void)tarGzipFileAtPath:(NSString *)sourcePath
                   toPath:(NSString *)destinationPath
               completion:(void(^)(NSError *))completion {
    NSString *temporaryPath = [self temporaryFilePathForPath:destinationPath];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    [self tarFileAtPath:sourcePath toPath:temporaryPath completion:^(NSError *tarError) {
        [progress resignCurrent];
        if (tarError != nil) {
            completion(tarError);
            return;
        }
        [progress becomeCurrentWithPendingUnitCount:1];
        [self gzipFileAtPath:temporaryPath toPath:destinationPath completion:^(NSError *gzipError) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:&error];
            [progress resignCurrent];
            if (gzipError != nil) {
                error = gzipError;
            }
            completion(error);
        }];
    }];
}

- (NSString *)temporaryFilePathForPath:(NSString *)path {
    NSString *UUIDString = [[NSUUID UUID] UUIDString];
    NSString *filename = [[path lastPathComponent] stringByDeletingPathExtension];
    NSString *temporaryFile = [filename stringByAppendingFormat:@"-%@",UUIDString];
    NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:temporaryFile];
    if (![[temporaryPath pathExtension] isEqualToString:@"tar"]) {
        temporaryPath = [temporaryPath stringByAppendingPathExtension:@"tar"];
    }
    return temporaryPath;
}

@end
