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

``` swift
override func viewDidLoad() {
    super.viewDidLoad()
    var options: Sumo.Session.Options = Sumo.Session.Options()
    options.imageTargetSize = CGSize(width: 500, height: 500)
    Sumo.shared.startSession(options: options)
}
```

For example in CollectionView's `func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)` `func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath)`

``` swift
func didSelectItem(indexPath: IndexPath, asset: PHAsset) {
    Sumo.shared.startWorflow(asset.localIdentifier) { (error) in
        if let error = error {
            debugPrint(error)
            return
        }
    }
}

func didDeselectItem(indexPath: IndexPath, asset: PHAsset) {
    Sumo.shared.cancel(asset.localIdentifier)
}
```
