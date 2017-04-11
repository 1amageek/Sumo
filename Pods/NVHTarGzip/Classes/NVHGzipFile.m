//
//  NVHGzip.m
//  Pods
//
//  Created by Niels van Hoorn on 26/03/14.
//
//

#import <zlib.h>
#import "NVHGzipFile.h"
#import "NSFileManager+NVHFileSize.h"

NSString *const NVHGzipFileZlibErrorDomain = @"io.nvh.targzip.zlib.error";


typedef NS_ENUM(NSInteger, NVHGzipFileErrorType)
{
    NVHGzipFileErrorTypeNone = 0,
    NVHGzipFileErrorTypeDecompressionFailed = -1,
    NVHGzipFileErrorTypeUnexpectedZlibState = -2,
    NVHGzipFileErrorTypeSourceOrDestinationFilePathIsNil = -3,
    NVHGzipFileErrorTypeCompressionFailed = -4,
    NVHGzipFileErrorTypeUnknown = -999
};


@interface NVHGzipFile ()

@property (nonatomic,assign) CGFloat fileSizeFraction;

@end


@implementation NVHGzipFile

- (BOOL)inflateToPath:(NSString *)destinationPath error:(NSError **)error {
    [self setupProgress];
    return [self innerInflateToPath:destinationPath error:error];
}

- (void)inflateToPath:(NSString *)destinationPath completion:(void(^)(NSError *))completion {
    [self setupProgress];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self innerInflateToPath:destinationPath error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    });
}

- (BOOL)innerInflateToPath:(NSString *)destinationPath error:(NSError **)error {
    [self updateProgressVirtualTotalUnitCountWithFileSize];
    
    NVHGzipFileErrorType result = NVHGzipFileErrorTypeNone;
    
    if (self.filePath && destinationPath)
    {
        [[NSFileManager defaultManager] createFileAtPath:destinationPath contents:nil attributes:nil];
        result = [self inflateGzip:self.filePath destination:destinationPath];
    }
    else
    {
        result = NVHGzipFileErrorTypeSourceOrDestinationFilePathIsNil;
    }

    BOOL success = (result == NVHGzipFileErrorTypeNone);

    if (!success && error != NULL) {
        NSString *localizedDescription = nil;

        switch (result) {
            case NVHGzipFileErrorTypeDecompressionFailed:
                localizedDescription = NSLocalizedString(@"Decompression failed", @"");
                break;
            case NVHGzipFileErrorTypeUnexpectedZlibState:
                localizedDescription = NSLocalizedString(@"Unexpected state from zlib", @"");
                break;
            case NVHGzipFileErrorTypeSourceOrDestinationFilePathIsNil:
                localizedDescription = NSLocalizedString(@"Source or destination path is nil", @"");
                break;
            case NVHGzipFileErrorTypeUnknown:
                localizedDescription = NSLocalizedString(@"Unknown error",@"");
                break;
            default:
                localizedDescription = @"";
                break;
        }

        *error = [NSError errorWithDomain:NVHGzipFileZlibErrorDomain
                                     code:result
                                 userInfo:@{NSLocalizedDescriptionKey:localizedDescription}];
    }

    return success;
}

- (NSInteger)inflateGzip:(NSString *)sourcePath
             destination:(NSString *)destinationPath {
    CFWriteStreamRef writeStream = (__bridge CFWriteStreamRef)[NSOutputStream outputStreamToFileAtPath:destinationPath append:NO];
    CFWriteStreamOpen(writeStream);
    
	// Convert source path into something a C library can handle
	const char *sourceCString = [sourcePath cStringUsingEncoding:NSASCIIStringEncoding];
    
	gzFile *sourceGzFile = gzopen(sourceCString, "rb");
    
	unsigned int bufferLength = 1024*256;	//Thats like 256Kb
	void *buffer = malloc(bufferLength);
    
    NVHGzipFileErrorType errorType = NVHGzipFileErrorTypeNone;
	while (true)
	{
		NSInteger readBytes = gzread(sourceGzFile, buffer, bufferLength);
        NSInteger dataOffSet = gzoffset(sourceGzFile);
        [self updateProgressVirtualCompletedUnitCount:dataOffSet];
		if (readBytes > 0)
		{
            CFIndex writtenBytes = CFWriteStreamWrite(writeStream, buffer, readBytes);
            if (writtenBytes <= 0)
            {
                errorType = NVHGzipFileErrorTypeDecompressionFailed;
                break;
            }
		}
		else if (readBytes == 0)
        {
			break;
        }
		else
        {
            if  (readBytes == -1)
            {
                errorType =  NVHGzipFileErrorTypeDecompressionFailed;
                break;
            }
            else
            {
                errorType =  NVHGzipFileErrorTypeUnexpectedZlibState;
                break;
            }
        }
	}
    [self updateProgressVirtualCompletedUnitCountWithTotal];
	gzclose(sourceGzFile);
	free(buffer);
    CFWriteStreamClose(writeStream);
	return errorType;
}

- (BOOL)deflateFromPath:(NSString *)sourcePath error:(NSError **)error {
    [self setupProgress];
    return [self innerDeflateFromPath:sourcePath error:error];
}

- (void)deflateFromPath:(NSString *)sourcePath completion:(void(^)(NSError *))completion {
    [self setupProgress];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self innerDeflateFromPath:sourcePath error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    });
}

- (BOOL)innerDeflateFromPath:(NSString *)sourcePath error:(NSError **)error {
    [self updateProgressVirtualTotalUnitCount:[[NSFileManager defaultManager] fileSizeOfItemAtPath:sourcePath]];
    
    NVHGzipFileErrorType result = NVHGzipFileErrorTypeNone;
    
    if (self.filePath && sourcePath)
    {
        result = [self deflateToGzip:self.filePath source:sourcePath];
    }
    else
    {
        result = NVHGzipFileErrorTypeSourceOrDestinationFilePathIsNil;
    }
    
    BOOL success = (result == NVHGzipFileErrorTypeNone);
    
    if (!success && error != NULL) {
        NSString *localizedDescription = nil;
        
        switch (result) {
            case NVHGzipFileErrorTypeCompressionFailed:
                localizedDescription = NSLocalizedString(@"Compression failed", @"");
                break;
            case NVHGzipFileErrorTypeUnexpectedZlibState:
                localizedDescription = NSLocalizedString(@"Unexpected state from zlib", @"");
                break;
            case NVHGzipFileErrorTypeSourceOrDestinationFilePathIsNil:
                localizedDescription = NSLocalizedString(@"Source or destination path is nil", @"");
                break;
            case NVHGzipFileErrorTypeUnknown:
                localizedDescription = NSLocalizedString(@"Unknown error",@"");
                break;
            default:
                localizedDescription = @"";
                break;
        }
        
        *error = [NSError errorWithDomain:NVHGzipFileZlibErrorDomain
                                     code:result
                                 userInfo:@{NSLocalizedDescriptionKey:localizedDescription}];
    }
    
    return success;
}

- (NSInteger)deflateToGzip:(NSString *)destinationPath
                    source:(NSString *)sourcePath {
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)[NSInputStream inputStreamWithFileAtPath:sourcePath];
    Boolean streamOpened = CFReadStreamOpen(readStream);
    if (!streamOpened)
    {
        return NVHGzipFileErrorTypeCompressionFailed;
    }
    
    // Convert destination path into something a C library can handle
    const char *destinationCString = [destinationPath cStringUsingEncoding:NSASCIIStringEncoding];
    
    gzFile *destinationGzFile = gzopen(destinationCString, "wb");
    
    unsigned int bufferLength = 1024*256;	//Thats like 256Kb
    void *buffer = malloc(bufferLength);
    NSInteger totalReadBytes = 0;
    
    NVHGzipFileErrorType errorType = NVHGzipFileErrorTypeNone;
    while (true)
    {
        NSInteger readBytes = CFReadStreamRead(readStream, buffer, bufferLength);
        totalReadBytes += readBytes;
        [self updateProgressVirtualCompletedUnitCount:(long long)totalReadBytes];
        if (readBytes > 0)
        {
            int writtenBytes = gzwrite(destinationGzFile, buffer, (unsigned int)readBytes);
            if (writtenBytes <= 0)
            {
                errorType = NVHGzipFileErrorTypeCompressionFailed;
                break;
            }
        }
        else if (readBytes == 0)
        {
            break;
        }
        else
        {
            if  (readBytes == -1)
            {
                errorType = NVHGzipFileErrorTypeCompressionFailed;
                break;
            }
            else
            {
                errorType = NVHGzipFileErrorTypeUnexpectedZlibState;
                break;
            }
        }
    }
    [self updateProgressVirtualCompletedUnitCountWithTotal];
    CFReadStreamClose(readStream);
    int gzError = gzclose(destinationGzFile);
    if (gzError != Z_OK)
    {
        errorType = NVHGzipFileErrorTypeUnexpectedZlibState;
    }
    free(buffer);
    return errorType;
}

@end
