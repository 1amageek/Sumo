//
//  NVHTarFile.m
//  Pods
//
//  Created by Niels van Hoorn on 26/03/14.
//
// Based on NSFileManager+Tar.m by Mathieu Hausherr Octo Technology on 25/11/11.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//



#pragma mark - Definitions

// Logging mode
// Comment this line for production
//#define TAR_VERBOSE_LOG_MODE

// const definition
#define TAR_BLOCK_SIZE                  512
#define TAR_TYPE_POSITION               156
#define TAR_NAME_POSITION               0
#define TAR_NAME_SIZE                   100
#define TAR_SIZE_POSITION               124
#define TAR_SIZE_SIZE                   12
#define TAR_MAX_BLOCK_LOAD_IN_MEMORY    100


// Define structure of POSIX 'ustar' tar header.
// Provided by libarchive.
#define	USTAR_name_offset 0
#define	USTAR_name_size 100
#define	USTAR_mode_offset 100
#define	USTAR_mode_size 6
#define	USTAR_mode_max_size 8
#define	USTAR_uid_offset 108
#define	USTAR_uid_size 6
#define	USTAR_uid_max_size 8
#define	USTAR_gid_offset 116
#define	USTAR_gid_size 6
#define	USTAR_gid_max_size 8
#define	USTAR_size_offset 124
#define	USTAR_size_size 11
#define	USTAR_size_max_size 12
#define	USTAR_mtime_offset 136
#define	USTAR_mtime_size 11
#define	USTAR_mtime_max_size 11
#define	USTAR_checksum_offset 148
#define	USTAR_checksum_size 8
#define	USTAR_typeflag_offset 156
#define	USTAR_typeflag_size 1
#define	USTAR_linkname_offset 157
#define	USTAR_linkname_size 100
#define	USTAR_magic_offset 257
#define	USTAR_magic_size 6
#define	USTAR_version_offset 263
#define	USTAR_version_size 2
#define	USTAR_uname_offset 265
#define	USTAR_uname_size 32
#define	USTAR_gname_offset 297
#define	USTAR_gname_size 32
#define	USTAR_rdevmajor_offset 329
#define	USTAR_rdevmajor_size 6
#define	USTAR_rdevmajor_max_size 8
#define	USTAR_rdevminor_offset 337
#define	USTAR_rdevminor_size 6
#define	USTAR_rdevminor_max_size 8
#define	USTAR_prefix_offset 345
#define	USTAR_prefix_size 155
#define	USTAR_padding_offset 500
#define	USTAR_padding_size 12

// Error const
#define TAR_ERROR_DOMAIN                       @"io.nvh.targzip.tar.error"
#define TAR_ERROR_CODE_BAD_BLOCK               1
#define TAR_ERROR_CODE_SOURCE_NOT_FOUND        2

#import "NVHTarFile.h"

@interface NVHTarFile()
@end

@implementation NVHTarFile

#pragma mark - Tar unpacking

- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path error:(NSError **)error {
    [self setupProgress];
    return [self innerCreateFilesAndDirectoriesAtPath:path error:error];
}

- (void)createFilesAndDirectoriesAtPath:(NSString *)destinationPath completion:(void (^)(NSError *))completion {
    [self setupProgress];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError* error = nil;
        [self innerCreateFilesAndDirectoriesAtPath:destinationPath error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    });
}

- (BOOL)innerCreateFilesAndDirectoriesAtPath:(NSString *)path error:(NSError **)error {
    [self updateProgressVirtualTotalUnitCountWithFileSize];
    BOOL result = NO;
    NSFileManager *filemanager = [NSFileManager defaultManager];
    if (self.filePath && [filemanager fileExistsAtPath:self.filePath]) {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
        result = [self createFilesAndDirectoriesAtPath:path withTarObject:fileHandle size:self.fileSize error:error];
        [fileHandle closeFile];
    } else {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: (self.filePath ? @"Source file not found" : @"Source file path is nil") };
        if (error != NULL) {
            *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN code:TAR_ERROR_CODE_SOURCE_NOT_FOUND userInfo:userInfo];
        }
    }
    return result;
}

- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path withTarObject:(id)object size:(unsigned long long)size error:(NSError **)error
{
    NSFileManager *filemanager = [NSFileManager defaultManager];
    
    [filemanager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]; //Create path on filesystem
    
    unsigned long long location = 0; // Position in the file
    while (location < size) {
        [self updateProgressVirtualCompletedUnitCount:location];
        unsigned long long blockCount = 1; // 1 block for the header
        switch ([NVHTarFile typeForObject:object atOffset:location]) {
            case '0':   // It's a File,
            case '\0':  // For backward compatibility
            {
                @autoreleasepool {
                    NSString *name = [NVHTarFile nameForObject:object atOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                    NSLog(@"UNTAR - file - %@", name);
#endif
                    NSString *filePath = [path stringByAppendingPathComponent:name]; // Create a full path from the name
                    
                    unsigned long long objectSize = [NVHTarFile sizeForObject:object atOffset:location];
                    
                    if (objectSize == 0 && name.length) {
#ifdef TAR_VERBOSE_LOG_MODE
                        NSLog(@"UNTAR - empty_file - %@", filePath);
#endif
                        NSError *writeError;
                        BOOL copied = [@"" writeToFile:filePath
                                            atomically:YES
                                              encoding:NSUTF8StringEncoding
                                                 error:&writeError];
                        if (!copied) {
#ifdef TAR_VERBOSE_LOG_MODE
                            NSLog(@"UNTAR - error during creating a directrory for a file - %@", writeError);
#endif
                        }
                        break;
                    }
                    
                    blockCount += (objectSize - 1) / TAR_BLOCK_SIZE + 1; // size/TAR_BLOCK_SIZE rounded up
                    
                    // The name field is the file name of the file,
                    // with directory names (if any) preceding the file name, separated by slashes.
                    if ([name lastPathComponent].length != name.length) {
                        NSString *directoryPath = [[path stringByAppendingPathComponent:name]
                                                   stringByDeletingLastPathComponent];
                        NSError *createError;
                        BOOL created = [filemanager createDirectoryAtPath:directoryPath
                                              withIntermediateDirectories:YES
                                                               attributes:nil
                                                                    error:&createError];
                        if (!created) {
#ifdef TAR_VERBOSE_LOG_MODE
                            NSLog(@"UNTAR - error during writing empty_file - %@", createError);
#endif
                        }
                    }
                    
                    [self writeFileDataForObject:object
                                      atLocation:(location + TAR_BLOCK_SIZE)
                                      withLength:objectSize
                                          atPath:filePath];
                }
                break;
            }
                
            case '5': // It's a directory
            {
                @autoreleasepool {
                    NSString *name = [NVHTarFile nameForObject:object atOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                    NSLog(@"UNTAR - directory - %@", name);
#endif
                    // Create a full path from the name
                    NSString *directoryPath = [path stringByAppendingPathComponent:name];
                    NSError *createError;
                    BOOL created = [filemanager createDirectoryAtPath:directoryPath
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:&createError]; //Write the directory on filesystem
                    if (!created) {
#ifdef TAR_VERBOSE_LOG_MODE
                        NSLog(@"UNTAR - error during creating a directrory - %@", createError);
#endif
                    }
                }
                break;
            }
            case '1':
            case '2':
            case '3':
            case '4':
            case '6':
            case '7':
            case 'x':
            case 'g': // It's not a file neither a directory
            {
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - unsupported block");
#endif
                @autoreleasepool {
                    unsigned long long objectSize = [NVHTarFile sizeForObject:object atOffset:location];
                    blockCount += ceil(objectSize / TAR_BLOCK_SIZE);
                }
                break;
            }
                
            default: // It's not a tar type
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Invalid block type found"
                                                                     forKey:NSLocalizedDescriptionKey];
                
                if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN
                                                                code:TAR_ERROR_CODE_BAD_BLOCK
                                                            userInfo:userInfo];
                
                return NO;
            }
        }
        
        location += blockCount * TAR_BLOCK_SIZE;
    }
    [self updateProgressVirtualCompletedUnitCountWithTotal];
    return YES;
}

#pragma mark Private methods implementation

+ (char)typeForObject:(id)object atOffset:(unsigned long long)offset
{
    char type;
    NSUInteger location = (NSUInteger)offset + TAR_TYPE_POSITION;
    memcpy(&type, [self dataForObject:object inRange:NSMakeRange(location, 1) orLocation:offset + TAR_TYPE_POSITION andLength:1].bytes, 1);
    return type;
}

+ (NSString *)nameForObject:(id)object atOffset:(unsigned long long)offset
{
    char nameBytes[TAR_NAME_SIZE + 1]; // TAR_NAME_SIZE+1 for nul char at end
    
    memset(&nameBytes, '\0', TAR_NAME_SIZE + 1); // Fill byte array with nul char
    NSUInteger location = (NSUInteger)offset + TAR_NAME_POSITION;
    memcpy(&nameBytes, [self dataForObject:object inRange:NSMakeRange(location, TAR_NAME_SIZE) orLocation:offset + TAR_NAME_POSITION andLength:TAR_NAME_SIZE].bytes, TAR_NAME_SIZE);
    return [NSString stringWithCString:nameBytes encoding:NSASCIIStringEncoding];
}

+ (unsigned long long)sizeForObject:(id)object atOffset:(unsigned long long)offset
{
    char sizeBytes[TAR_SIZE_SIZE + 1]; // TAR_SIZE_SIZE+1 for nul char at end
    
    memset(&sizeBytes, '\0', TAR_SIZE_SIZE + 1); // Fill byte array with nul char
    NSUInteger location = (NSUInteger)offset + TAR_SIZE_POSITION;
    memcpy(&sizeBytes, [self dataForObject:object inRange:NSMakeRange(location, TAR_SIZE_SIZE) orLocation:offset + TAR_SIZE_POSITION andLength:TAR_SIZE_SIZE].bytes, TAR_SIZE_SIZE);
    return strtol(sizeBytes, NULL, 8); // Size is an octal number, convert to decimal
}

- (void)writeFileDataForObject:(id)object atLocation:(unsigned long long)location withLength:(unsigned long long)length atPath:(NSString *)path
{
    BOOL created = NO;
    if ([object isKindOfClass:[NSData class]]) {
        NSData *contents = [object subdataWithRange:NSMakeRange((NSUInteger)location, (NSUInteger)length)];
        created = [[NSFileManager defaultManager] createFileAtPath:path
                                                          contents:contents
                                                        attributes:nil]; //Write the file on filesystem
    } else if ([object isKindOfClass:[NSFileHandle class]]) {
        created = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        if (created) {
            NSFileHandle *destinationFile = [NSFileHandle fileHandleForWritingAtPath:path];
            [object seekToFileOffset:location];
            
            unsigned long long maxSize = TAR_MAX_BLOCK_LOAD_IN_MEMORY * TAR_BLOCK_SIZE;
            
            while (length > maxSize) {
                @autoreleasepool {
                    [destinationFile writeData:[object readDataOfLength:(NSUInteger)maxSize]];
                    location += maxSize;
                    length -= maxSize;
                }
            }
            [destinationFile writeData:[object readDataOfLength:(NSUInteger)length]];
            [destinationFile closeFile];
        }
    }
    
    if (!created) {
#ifdef TAR_VERBOSE_LOG_MODE
        NSLog(@"UNTAR - can't create file");
#endif
    }
}

+ (NSData *)dataForObject:(id)object inRange:(NSRange)range orLocation:(unsigned long long)location andLength:(unsigned long long)length
{
    if ([object isKindOfClass:[NSData class]]) {
        return [object subdataWithRange:range];
    } else if ([object isKindOfClass:[NSFileHandle class]]) {
        [object seekToFileOffset:location];
        return [object readDataOfLength:(NSUInteger)length];
    }
    
    return nil;
}

#pragma mark - Tar packing

- (BOOL)packFilesAndDirectoriesAtPath:(NSString *)path error:(NSError **)error
{
    [self setupProgress];
    return [self innerPackFilesAndDirectoriesAtPath:path error:error];
}

- (void)packFilesAndDirectoriesAtPath:(NSString *)sourcePath completion:(void (^)(NSError *))completion {
    [self setupProgress];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError* error = nil;
        [self innerPackFilesAndDirectoriesAtPath:sourcePath error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    });
}

- (BOOL)innerPackFilesAndDirectoriesAtPath:(NSString *)path error:(NSError **)error
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:path]) {
        [fileManager removeItemAtPath:self.filePath error:nil];
        [@"" writeToFile:self.filePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
        BOOL result = [self packFilesAndDirectoriesAtPath:path withTarObject:fileHandle size:self.fileSize error:error];
        [fileHandle closeFile];
        return result;
    }
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"File to be packed not found"
                                                         forKey:NSLocalizedDescriptionKey];
    
    if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN code:TAR_ERROR_CODE_SOURCE_NOT_FOUND userInfo:userInfo];
    
    return NO;
}

- (BOOL)packFilesAndDirectoriesAtPath:(NSString *)path withTarObject:(id)object size:(unsigned long long)size error:(NSError **)error
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtPath:path];
    NSArray *directoryEnumeratorObjects = [directoryEnumerator allObjects];
    [self updateProgressVirtualTotalUnitCount:[directoryEnumeratorObjects count]];
    int currentVirtualTotalUnit = 0;
    for (NSString *file in directoryEnumeratorObjects) {
        [self updateProgressVirtualCompletedUnitCount:currentVirtualTotalUnit];
        currentVirtualTotalUnit++;
        BOOL isDir = NO;
        [fileManager fileExistsAtPath:[path stringByAppendingPathComponent:file] isDirectory:&isDir];
        NSData *tarContent = [self binaryEncodeDataForPath:file inDirectory:path isDirectory:isDir];
        [object writeData:tarContent];
    }
    // Append two empty blocks to indicate end
    char block[TAR_BLOCK_SIZE*2];
    memset(&block, '\0', TAR_BLOCK_SIZE*2);
    [object writeData:[NSData dataWithBytes:block length:TAR_BLOCK_SIZE*2]];
    
    [self updateProgressVirtualCompletedUnitCountWithTotal];
    
    return YES;
}

- (NSData *)binaryEncodeDataForPath:(NSString *) path inDirectory:(NSString *)basepath  isDirectory:(BOOL) isDirectory{
    
    NSMutableData *tarData;
    char block[TAR_BLOCK_SIZE];
    
    if(isDirectory) {
        path = [path stringByAppendingString:@"/"];
    }
    //write header
    [self writeHeader:block forPath:path withBasePath:basepath isDirectory:isDirectory];
    tarData = [NSMutableData dataWithBytes:block length:TAR_BLOCK_SIZE];
    
    //write data
    if(!isDirectory) {
        [self writeDataFromPath: [basepath stringByAppendingPathComponent:path] toData:tarData];
    }
    return tarData;
}

static const char template_header[] = {
    /* name: 100 bytes */
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,
    /* Mode, space-null termination: 8 bytes */
    '0','0','0','0','0','0', ' ','\0',
    /* uid, space-null termination: 8 bytes */
    '0','0','0','0','0','0', ' ','\0',
    /* gid, space-null termination: 8 bytes */
    '0','0','0','0','0','0', ' ','\0',
    /* size, space termation: 12 bytes */
    '0','0','0','0','0','0','0','0','0','0','0', ' ',
    /* mtime, space termation: 12 bytes */
    '0','0','0','0','0','0','0','0','0','0','0', ' ',
    /* Initial checksum value: 8 spaces */
    ' ',' ',' ',' ',' ',' ',' ',' ',
    /* Typeflag: 1 byte */
    '0',			/* '0' = regular file */
    /* Linkname: 100 bytes */
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,
    /* Magic: 6 bytes, Version: 2 bytes */
    'u','s','t','a','r','\0', '0','0',
    /* Uname: 32 bytes */
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    /* Gname: 32 bytes */
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    /* rdevmajor + space/null padding: 8 bytes */
    '0','0','0','0','0','0', ' ','\0',
    /* rdevminor + space/null padding: 8 bytes */
    '0','0','0','0','0','0', ' ','\0',
    /* Prefix: 155 bytes */
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,
    /* Padding: 12 bytes */
    0,0,0,0,0,0,0,0, 0,0,0,0
};

- (void)writeHeader:(char *)buffer forPath:(NSString *)path withBasePath:(NSString *)basePath isDirectory:(BOOL)isDirectory {
    
    memcpy(buffer,&template_header, TAR_BLOCK_SIZE);
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[basePath stringByAppendingPathComponent:path] error:&error];
    int permissions = [[attributes objectForKey:NSFilePosixPermissions] shortValue];
    NSDate * modificationDate = [attributes objectForKey:NSFileModificationDate];
    long ownerId = [[attributes objectForKey:NSFileOwnerAccountID] longValue];
    long groupId = [[attributes objectForKey:NSFileGroupOwnerAccountID] longValue];
    NSString *ownerName = [attributes objectForKey:NSFileOwnerAccountName];
    NSString *groupName = [attributes objectForKey:NSFileGroupOwnerAccountName];
    unsigned long long fileSize = [[attributes objectForKey:NSFileSize] longLongValue];
    
    char nameChar[USTAR_name_size];
    [self writeString:path toChar:nameChar withLength:USTAR_name_size];
    char unameChar[USTAR_uname_size];
    [self writeString:ownerName toChar:unameChar withLength:USTAR_uname_size];
    char gnameChar[USTAR_gname_size];
    [self writeString:groupName toChar:gnameChar withLength:USTAR_gname_size];
    
    
    format_number(permissions & 07777, buffer+USTAR_mode_offset, USTAR_mode_size, USTAR_mode_max_size, 0);
    format_number(ownerId,
                  buffer + USTAR_uid_offset, USTAR_uid_size, USTAR_uid_max_size, 0);
    format_number(groupId,
                  buffer + USTAR_gid_offset, USTAR_gid_size, USTAR_gid_max_size, 0);
    
    format_number(fileSize, buffer + USTAR_size_offset, USTAR_size_size, USTAR_size_max_size, 0);
    
    format_number([modificationDate timeIntervalSince1970],
                  buffer + USTAR_mtime_offset, USTAR_mtime_size, USTAR_mtime_max_size, 0);
    
    unsigned long nameLength = strlen(nameChar);
    if (nameLength <= USTAR_name_size)
        memcpy(buffer + USTAR_name_offset, nameChar, nameLength);
    else {
        /* Store in two pieces, splitting at a '/'. */
        const char *p = strchr(nameChar + nameLength - USTAR_name_size - 1, '/');
        /*
         * Look for the next '/' if we chose the first character
         * as the separator.  (ustar format doesn't permit
         * an empty prefix.)
         */
        if (p == nameChar)
            p = strchr(p + 1, '/');
        memcpy(buffer + USTAR_prefix_offset, nameChar, p - nameChar);
        memcpy(buffer + USTAR_name_offset, p + 1,
               nameChar + nameLength - p - 1);
    }
    
    memcpy(buffer+USTAR_uname_offset,unameChar,USTAR_uname_size);
    memcpy(buffer+USTAR_gname_offset,gnameChar,USTAR_gname_size);
    
    if(isDirectory) {
        format_number(0, buffer + USTAR_size_offset, USTAR_size_size, USTAR_size_max_size, 0);
        memset(buffer+USTAR_typeflag_offset,'5',USTAR_typeflag_size);
    }
    
    //Checksum
    int checksum = 0;
    for (int i = 0; i < TAR_BLOCK_SIZE; i++)
        checksum += 255 & (unsigned int)buffer[i];
    buffer[USTAR_checksum_offset + 6] = '\0';
    format_octal(checksum, buffer + USTAR_checksum_offset, 6);
}

#pragma mark Formatting
//Thanks to libarchive

//Format a number into a field, with some intelligence.
static int format_number(int64_t v, char *p, int s, int maxsize, int strict)
{
    int64_t limit;
    
    limit = ((int64_t)1 << (s*3));
    
    /* "Strict" only permits octal values with proper termination. */
    if (strict)
        return (format_octal(v, p, s));
    
    /*
     * In non-strict mode, we allow the number to overwrite one or
     * more bytes of the field termination.  Even old tar
     * implementations should be able to handle this with no
     * problem.
     */
    if (v >= 0) {
        while (s <= maxsize) {
            if (v < limit)
                return (format_octal(v, p, s));
            s++;
            limit <<= 3;
        }
    }
    
    /* Base-256 can handle any number, positive or negative. */
    return (format_256(v, p, maxsize));
}

//Format a number into the specified field using base-256.
static int format_256(int64_t v, char *p, int s)
{
    p += s;
    while (s-- > 0) {
        *--p = (char)(v & 0xff);
        v >>= 8;
    }
    *p |= 0x80; /* Set the base-256 marker bit. */
    return (0);
}

//Format a number into the specified field.
static int format_octal(int64_t v, char *p, int s)
{
    int len;
    
    len = s;
    
    /* Octal values can't be negative, so use 0. */
    if (v < 0) {
        while (len-- > 0)
            *p++ = '0';
        return (-1);
    }
    
    p += s;		/* Start at the end and work backwards. */
    while (s-- > 0) {
        *--p = (char)('0' + (v & 7));
        v >>= 3;
    }
    
    if (v == 0)
        return (0);
    
    /* If it overflowed, fill field with max value. */
    while (len-- > 0)
        *p++ = '7';
    
    return (-1);
}

- (void)writeDataFromPath:(NSString *)path toData:(NSMutableData*)data {
    NSData *content = [NSData dataWithContentsOfFile:path];
    NSUInteger contentSize = [content length];
    unsigned long padding =  (TAR_BLOCK_SIZE - (contentSize % TAR_BLOCK_SIZE)) % TAR_BLOCK_SIZE ;
    char buffer[padding];
    memset(&buffer, '\0', padding);
    [data appendData:content];
    [data appendBytes:buffer length:padding];
}

- (void)writeString:(NSString*)string toChar:(char*)charArray withLength:(NSInteger)size
{
    NSData *stringData = [string dataUsingEncoding:NSASCIIStringEncoding];
    memset(charArray, '\0', size);
    [stringData getBytes:charArray length:[stringData length]];
}

@end
