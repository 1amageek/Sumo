# Sumo

<img src="https://github.com/1amageek/Sumo/blob/master/sumo.png" width="240px">

Sumo is a library that prepares for fast upload for iOS.
It is effective when uploading by selecting images continuously.
Sumo will prepare for uploading immediately after the image is selected.
Multiple selected images are compiled into one file and compressed.
One compressed file can communicate without overhead.

<img src="https://github.com/1amageek/Sumo/blob/master/overview.png" width="640px">


## Feature 🎉
- ☑️  Non blocking Main thread.
- ☑️  Fast resizing.
- ☑️  Task is cancelable.
- ☑️  Multi sessions.


## Usage

Sumo consists of sessions and tasks.
Multiple tasks are associated with one session, and you can obtain obtain artifacts by zip the session.

``` swift
override func viewDidLoad() {
    super.viewDidLoad()
    var options: Sumo.Session.Options = Sumo.Session.Options()
    // Target of image resizing
    options.imageTargetSize = CGSize(width: 500, height: 500)
    Sumo.shared.startSession(options: options)
}
```

For example in CollectionView's

- `func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)` 
- `func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath)`

``` swift
// Compress and process the image in the background.
func didSelectItem(indexPath: IndexPath, asset: PHAsset) {
    Sumo.shared.startWorflow(asset.localIdentifier) { (error) in
        if let error = error {
            debugPrint(error)
            return
        }
    }
}

// Cancel the image being compressed.
func didDeselectItem(indexPath: IndexPath, asset: PHAsset) {
    Sumo.shared.cancel(asset.localIdentifier)
}
```

``` swift
// Stop all processing.
@objc private func cancel() {
    Sumo.shared.stop()
}

// Cancel the task being processed. The session will continue to remain.
@objc private func reset() {
    Sumo.shared.reset()
}

// Compress the resized photo to zip.
@objc private func zip() {
    Sumo.shared.zip { (url, error) in
        // Transfer to any server.
    }
}
```
