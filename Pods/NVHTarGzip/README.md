# NVHTarGzip

[![Version](http://cocoapod-badges.herokuapp.com/v/NVHTarGzip/badge.png)](http://cocoadocs.org/docsets/NVHTarGzip)
[![Platform](http://cocoapod-badges.herokuapp.com/p/NVHTarGzip/badge.png)](http://cocoadocs.org/docsets/NVHTarGzip)

This is an *ObjC* library for *tarring*/*untarring* and *gzipping*/*ungzipping* that directly manipulates files. It isn't implemented as a category on `NSData` (unlike [GZIP](https://github.com/nicklockwood/GZIP) or [Godzippa](https://github.com/mattt/Godzippa)) so the full file doesn't have to be first loaded into memory.

The *tar* implementation is based on [Light-Untar-for-iOS](https://github.com/mhausherr/Light-Untar-for-iOS), but is extended to include progress reporting through `NSProgress`.

## Usage

### Asynchronous

#### Inflate Gzip file

```objective-c
[[NVHTarGzip shared] unGzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* gzipError) {
    if (gzipError != nil) {
        NSLog(@"Error ungzipping %@", gzipError);
    }
}];
```

#### Untar file

```objective-c
[[NVHTarGzip shared] unTarFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* tarError) {
    if (tarError != nil) {
        NSLog(@"Error untarring %@", tarError);
    }
}];
```

#### Inflate Gzip and Untar

```objective-c
[[NVHTarGzip shared] unTarGzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* error) {
    if (error != nil) {
        NSLog(@"Error extracting %@", error);
    }
}];
```

#### Deflate Gzip file

```objective-c
[[NVHTarGzip shared] gzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* gzipError) {
    if (gzipError != nil) {
        NSLog(@"Error gzipping %@", gzipError);
    }
}];
```

#### Tar file

```objective-c
[[NVHTarGzip shared] tarFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* tarError) {
    if (tarError != nil) {
        NSLog(@"Error tarring %@", tarError);
    }
}];
```

#### Deflate Gzip and Tar

```objective-c
[[NVHTarGzip shared] tarGzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* error) {
    if (error != nil) {
        NSLog(@"Error packing %@", error);
    }
}];
```


### Synchronous

#### Inflate Gzip file

```objective-c
[[NVHTarGzip shared] unGzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* gzipError) {
    if (gzipError != nil) {
        NSLog(@"Error ungzipping %@", gzipError);
    }
}];
```

#### Untar file

```objective-c
[[NVHTarGzip shared] unTarFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* tarError) {
    if (tarError != nil) {
        NSLog(@"Error untarring %@", tarError);
    }
}];
```

#### Inflate Gzip and Untar

```objective-c
[[NVHTarGzip shared] unTarGzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* error) {
    if (error != nil) {
        NSLog(@"Error extracting %@", error);
    }
}];
```

#### Deflate Gzip file

```objective-c
[[NVHTarGzip shared] gzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* gzipError) {
    if (gzipError != nil) {
        NSLog(@"Error gzipping %@", gzipError);
    }
}];
```

#### Tar file

```objective-c
[[NVHTarGzip shared] tarFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* tarError) {
    if (tarError != nil) {
        NSLog(@"Error untarring %@", tarError);
    }
}];
```

#### Deflate Gzip and Tar

```objective-c
[[NVHTarGzip shared] tarGzipFileAtPath:sourcePath toPath:destinationPath completion:^(NSError* error) {
    if (error != nil) {
        NSLog(@"Error extracting %@", error);
    }
}];
```

##### Note
Sequential `tar.gz` packing and unpacking will either *tar* or *ungzip* the intermediate `tar` file to a temporary-directory, and subsequently *gzip* or *untar* it. After *gzipping*/*untarring*, the temporary-file is deleted. You can customize the cachePath by setting it on the singleton object before extracting:

```objective-c
[[NVHTarGzip shared] setCachePath:customCachePath];
```

### Progress 

`NVHTarGzip` uses `NSProgress` to handle progress reporting. To keep track of progress create your own progress instance and use KVO to inspect the `fractionCompleted` property. See the [documentation of NSProgress](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSProgress_Class/Reference/Reference.html) and [this great article](http://oleb.net/blog/2014/03/nsprogress/) by [Ole Begemann](https://github.com/ole) for more information.

```objective-c
NSProgress* progress = [NSProgress progressWithTotalUnitCount:1];
NSString* keyPath = NSStringFromSelector(@selector(fractionCompleted));
[progress addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionInitial context:NVHProgressFractionCompletedObserverContext];
[progress becomeCurrentWithPendingUnitCount:1];
[[NVHTarGzip shared] unTarGzipFileAtPath:self.demoSourceFilePath toPath:self.demoDestinationFilePath completion:^(NSError* error) {
    [progress resignCurrent];
    [progress removeObserver:self forKeyPath:keyPath];
}];
```

Checkout a full usage example in the example project; clone the repo, and run `pod install` from the Example directory first.

## Todo

Add streaming support (`NSStream`). This would allow the usage of an intermediate file for `tar.gz` packing and unpacking, thus speeding things a bit.

Pull requests are welcome!

## Installation

*NVHTarGzip* is available through [CocoaPods](http://cocoapods.org), to install
it simply add the following line to your `Podfile`:

```ruby
pod "NVHTarGzip"
```

## Author

Niels van Hoorn, nvh@nvh.io

## License

*NVHTarGzip* is available under the *MIT license*. See the `LICENSE` file for more info.