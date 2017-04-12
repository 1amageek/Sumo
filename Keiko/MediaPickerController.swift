//
//  MediaPickerController.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/03.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import UIKit
import Photos

protocol MediaPickerDelegate: class {
    func MediaPickerController(controller: MediaPickerController, didFinishPickingAssets assets: [PHAsset]) -> Void
    func MediaPickerControllerDidCancel(controller: MediaPickerController) -> Void
}

class MediaPickerNavigationHeader: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(titleLabel)
        self.addSubview(detailLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.sizeToFit()
        detailLabel.sizeToFit()
        titleLabel.center = CGPoint(x: bounds.width/2, y: bounds.height/2 - titleLabel.bounds.height/2)
        detailLabel.center = CGPoint(x: bounds.width/2, y: bounds.height/2 + detailLabel.bounds.height/2 )
    }
    
    var title: String? {
        didSet {
            titleLabel.text = title
            setNeedsLayout()
        }
    }
    
    var detail: String? {
        didSet {
            detailLabel.text = detail
            setNeedsLayout()
        }
    }
    
    private(set) lazy var titleLabel: UILabel = {
        var titleLabel: UILabel = UILabel(frame: .zero)
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        return titleLabel
    }()
    
    private(set) lazy var detailLabel: UILabel = {
        var detailLabel: UILabel = UILabel(frame: .zero)
        detailLabel.numberOfLines = 1
        detailLabel.font = UIFont.systemFont(ofSize: 10)
        return detailLabel
    }()
    
}

class MediaPickerController: UIViewController, MediaPickerHeaderDelegate, UICollectionViewDataSource, UICollectionViewDelegate {

    struct MediaType: OptionSet {
        let rawValue: Int
        static let image = MediaType(rawValue: 1 << 0)
        static let video = MediaType(rawValue: 1 << 1)
        static let all: MediaType = [.image, .video]
    }
    
    let imageManager: PHCachingImageManager = PHCachingImageManager()
    
    weak var delegate: MediaPickerDelegate?
    
    let uploadPossibleTime: TimeInterval = 180
    
    var mediaType: MediaType = .all {
        didSet {
            reloadData()
        }
    }
    
    var sections: [SectionInfo] = []
    
    var assetCollections: PHFetchResult<PHAssetCollection>? {
        didSet {
            reloadData()
        }
    }
    
    // PHAssetのlocalIdentifierをセットするとそのPHAssetを表示させないようにする
    var ignoreLocalIdentifiers: [String] = []
    
    /**
     条件に合わせてdatasourceをリロードする
    */
    func reloadData() {
        self.assetCollections?.enumerateObjects({ (assetCollection, index, stop) in
            let options: PHFetchOptions = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let localIDsPredicate: NSPredicate = NSPredicate(format: "NOT (localIdentifier IN %@)", self.ignoreLocalIdentifiers)
            switch self.mediaType {
            case [.video]:
                let mediaTypePredicate: NSPredicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [localIDsPredicate, mediaTypePredicate])
            case [.image]:
                let mediaTypePredicate: NSPredicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [localIDsPredicate, mediaTypePredicate])
            default:
                options.predicate = localIDsPredicate
            }
            
            let assetsFetchResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: assetCollection, options: options)
            if assetsFetchResult.count > 0 {
                self.sections.append(SectionInfo(fetchResult: assetsFetchResult, assetCollection: assetCollection))
            }
            
        })
        if self.isViewLoaded {
            self.collectionView.reloadData()
        }
    }
    
    var showHeader: Bool {
        return self.sections.count > 0
    }
    var hasReachedNumberOfPhotos: Bool { return limitOfPhotos <= countOfPhotos }
    var hasReachedNumberOfVideos: Bool { return limitOfVidoes <= countOfVideos }
    
    var limitOfPhotos: Int {
        return 15
    }
    
    var limitOfVidoes: Int {
        return 3
    }
    
    // MARK: -
    
    override func loadView() {
        super.loadView()
        self.view.backgroundColor = .white
        self.view.addSubview(collectionView)
        self.collectionView.register(MediaPickerCell.self, forCellWithReuseIdentifier: "MediaPickerCell")
        self.collectionView.register(MediaPickerHeader.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "MediaPickerHeader")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.toolbar.isTranslucent = false
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        self.navigationController?.setToolbarHidden(false, animated: false)
        self.navigationItem.titleView = self.headerView
        self.navigationItem.rightBarButtonItems =
            [UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(reset)),
             UIBarButtonItem(title: "Zip", style: .plain, target: self, action: #selector(zip)),
             UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel)),]
        
        let statusHeight: CGFloat = UIApplication.shared.statusBarFrame.height
        let navigationBarHeight: CGFloat = self.navigationController?.navigationBar.frame.height ?? 0
        let toolbarHeight: CGFloat = self.navigationController?.toolbar.frame.height ?? 0
        self.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: statusHeight + navigationBarHeight + toolbarHeight, right: 0)
        self.collectionView.allowsMultipleSelection = true
        
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                
                DispatchQueue.main.async {
                    if self.assetCollections == nil {
                        let options: PHFetchOptions = PHFetchOptions()
                        options.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                        self.assetCollections = PHAssetCollection.fetchAssetCollections(with: .moment, subtype: .albumRegular, options: options)
                    }
                    
                    self.updateTitle()
                    PHPhotoLibrary.shared().register(self)
                }
                            
            default: break
            }
        }
        var options: Sumo.Session.Options = Sumo.Session.Options()
        options.imageTargetSize = CGSize(width: 500, height: 500)
        Sumo.shared.startSession(options: options)
        
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.sections.count 
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.sections[section].fetchResult.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: MediaPickerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaPickerCell", for: indexPath as IndexPath) as! MediaPickerCell
        configure(cell: cell, atIndexPath: indexPath)
        return cell
    }

    func configure(cell: MediaPickerCell, atIndexPath indexPath: IndexPath) {
        
        let asset: PHAsset = self.assetAtIndexPath(indexPath: indexPath)
        cell.id = asset.localIdentifier
        
        switch asset.mediaType {
        case .image:
            if self.collectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false {
                cell.imageView.alpha = self.hasReachedNumberOfPhotos ? 0.6 : 1
            }
            let options: PHImageRequestOptions = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            options.deliveryMode = .opportunistic
            cell.imageRequestID = self.imageManager.requestImage(for: asset, targetSize: self.assetGridScaleSize, contentMode: .aspectFill, options: options) { (image, info) in
                if let id: String = cell.id, id == asset.localIdentifier {
                    cell.image = image
                }
            }
        case .video:
            if self.collectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false {
                cell.imageView.alpha = self.hasReachedNumberOfVideos ? 0.6 : 1
            }
            let duration: TimeInterval = asset.duration
            let min: Int = Int(duration / 60)
            let sec: Int = Int(duration.truncatingRemainder(dividingBy: 60))
            cell.canUpload = duration < self.uploadPossibleTime
            cell.videoLength = String(format: "%ld:%02ld", min, sec)
            let options: PHImageRequestOptions = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            options.deliveryMode = .opportunistic
            cell.imageRequestID = self.imageManager.requestImage(for: asset, targetSize: self.assetGridScaleSize, contentMode: .aspectFill, options: options) { (image, info) in
                if let id: String = cell.id, id == asset.localIdentifier {
                    cell.image = image
                }
            }
        default: break
        }
    }
 
    private func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: MediaPickerCell, forItemAt indexPath: IndexPath) {
        cell.imageView.stopAnimating()
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if showHeader {
            if UICollectionElementKindSectionHeader == kind {
                let header: MediaPickerHeader = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "MediaPickerHeader", for: indexPath as IndexPath) as! MediaPickerHeader
                self.configure(header: header, at: indexPath)
                return header
            }
        }
        return UICollectionReusableView()
    }
    
    func configure(header: MediaPickerHeader, at indexPath: IndexPath) {
        let assetCollection: PHAssetCollection = self.sections[indexPath.section].assetCollection
        guard let startDate: Date = assetCollection.startDate else {
            return
        }
        header.delegate = self
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.M.d"
        header.title = dateFormatter.string(from: startDate)
        header.section = indexPath.section
        let numberOfItems: Int = collectionView.numberOfItems(inSection: indexPath.section)
        if let indexPaths: [IndexPath] = collectionView.indexPathsForSelectedItems {
            let items: [IndexPath] = indexPaths.filter({ (aIndexPath) -> Bool in
                return aIndexPath.section == indexPath.section
            })
            header.isSelected = items.count == numberOfItems
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if showHeader {
            let header: MediaPickerHeader = MediaPickerHeader(frame: self.view.bounds)
            return header.calculateSize()
        }
        return CGSize.zero
    }
    
    func shouldSelectHeader(header: MediaPickerHeader) -> Bool {
        return true
    }
    
    func header(header: MediaPickerHeader, didSelected selected: Bool) {
        let section: Int = header.section
        var hasReached: Bool = false
        (0..<self.collectionView.numberOfItems(inSection: section)).forEach { (index) in
            let indexPath: IndexPath = IndexPath(item: index, section: section)
            let asset: PHAsset = assetAtIndexPath(indexPath: indexPath)
            if selected {
                switch asset.mediaType {
                case .image where hasReachedNumberOfPhotos: fallthrough
                case .video where hasReachedNumberOfVideos: fallthrough
                case .video where !canUploadVideo(asset: asset):
                    header.isSelected = false
                    hasReached = true
                    break
                default:
                    self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                    didSelectItem(indexPath: indexPath, asset: asset)
                    selectWithAsset(asset: asset)
                }
            } else {
                self.collectionView.deselectItem(at: indexPath, animated: false)
                didDeselectItem(indexPath: indexPath, asset: asset)
                deSelectWithAsset(asset: asset)
            }
        }
        
        updateTitle()
        updateVisbleCells()
        
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let asset: PHAsset = assetAtIndexPath(indexPath: indexPath)
        switch asset.mediaType {
        case .image where hasReachedNumberOfPhotos:
            showReachAlert()
            return false
        case .video where hasReachedNumberOfVideos:
            showReachAlert()
            return false
        case .video where !canUploadVideo(asset: asset):
            showCanntUploadAlert()
            return false
        default: break
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset: PHAsset = assetAtIndexPath(indexPath: indexPath)
        selectWithAsset(asset: asset)
        didSelectItem(indexPath: indexPath, asset: asset)
        animateCell(indexPath: indexPath)
        updateTitle()
        updateVisbleCells()
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let asset: PHAsset = assetAtIndexPath(indexPath: indexPath)
        deSelectWithAsset(asset: asset)
        didDeselectItem(indexPath: indexPath, asset: asset)
        animateCell(indexPath: indexPath)
        updateTitle()
        updateVisbleCells()
    }
    
    func animateCell(indexPath: IndexPath) {
        let cell: MediaPickerCell = collectionView.cellForItem(at: indexPath) as! MediaPickerCell
        cell.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        UIView.animate(withDuration: 0.33, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3, options: .curveEaseInOut, animations: {
            cell.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    let margin: CGFloat = 4
    var assetGridSize: CGSize {
        let numberOfColumn: CGFloat = 3
        let screenSize: CGSize = UIScreen.main.bounds.size
        let side: CGFloat = (screenSize.width - (margin * (numberOfColumn - 1))) / numberOfColumn
        return CGSize(width: side, height: side)
    }
    
    var assetGridScaleSize: CGSize {
        let scale: CGFloat = UIScreen.main.scale
        return CGSize(width: assetGridSize.width * scale, height: assetGridSize.height * scale)
    }
    
    // MARK: -
    
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
    
    // MARK: - 
    
    private func selectWithAsset(asset: PHAsset) {
        switch asset.mediaType {
        case .image: countOfPhotos += 1
        case .video: countOfVideos += 1
        default: break
        }
    }
    
    private func deSelectWithAsset(asset: PHAsset) {
        switch asset.mediaType {
        case .image: countOfPhotos -= 1
        case .video: countOfVideos -= 1
        default: break
        }
    }
    
    var countOfPhotos: Int = 0
    var countOfVideos: Int = 0
    
    func updateTitle() {

        switch self.mediaType {
        case [.all]:
            self.headerView.detail = String(format: "%@ %ld/%ld  %@ %ld/%ld",
                                            "Photos",
                                            countOfPhotos, self.limitOfPhotos,
                                            "Videos",
                                            countOfVideos, self.limitOfVidoes
            )
        case [.video]:
            self.headerView.detail = String(format: "%@ %ld/%ld",
                                            "Videos",
                                            countOfVideos, self.limitOfVidoes
            )
        case [.image]:
            self.headerView.detail = String(format: "%@ %ld/%ld",
                                            "Photos",
                                            countOfPhotos, self.limitOfPhotos
            )
        default: break
            
        }
        
    }
    
    private func updateVisbleCells() {
        if #available(iOS 9.0, *) {
            self.collectionView.visibleSupplementaryViews(ofKind: UICollectionElementKindSectionHeader)
            
        } else {
            // Fallback on earlier versions
        }
        self.collectionView.indexPathsForVisibleItems.forEach({ (indexPath) in
            if let cell: MediaPickerCell = self.collectionView.cellForItem(at: indexPath) as? MediaPickerCell {
                _ = self.configure(cell: cell, atIndexPath: indexPath)
            }
        })
    }
    
    func assetAtIndexPath(indexPath: IndexPath) -> PHAsset {
        let assetsFetchResult: PHFetchResult<PHAsset> = self.sections[indexPath.section].fetchResult
        let asset: PHAsset = assetsFetchResult[indexPath.item] 
        return asset
    }
    
    func canUploadVideo(asset: PHAsset) -> Bool {
        return asset.duration < uploadPossibleTime
    }
    
    func showReachAlert() {
        if self.presentedViewController == nil {
            let alertController: UIAlertController = UIAlertController(title: nil, message: "選択の上限", preferredStyle: .alert)
            let ok: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(ok)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func showCanntUploadAlert() {
        if self.presentedViewController == nil {
            let alertController: UIAlertController = UIAlertController(title: nil, message: "アップロードできない", preferredStyle: .alert)
            let ok: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(ok)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - private function
    
    @objc private func upload() {
        if let assets: [PHAsset] = self.collectionView.indexPathsForSelectedItems?.flatMap({ self.assetAtIndexPath(indexPath: $0) }) {
            self.delegate?.MediaPickerController(controller: self, didFinishPickingAssets: assets)
        }
    }
    
    @objc private func cancel() {
        Sumo.shared.stop()
    }
    
    @objc private func reset() {
        Sumo.shared.reset()
    }
    
    @objc private func zip() {
        Sumo.shared.zip { (url, error) in
            
        }
    }
    
    @objc private func video() {
        // nothing
    }
    
    @objc private func _back() {
        back()
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    func back() {
        // override method
    }
    
    
    // MARK: - element
    

    private(set) lazy var selectPutAlbumSwitch: UISwitch = {
        let sw: UISwitch = UISwitch()
        sw.sizeToFit()
        sw.isOn = true
        return sw
    }()
    
    private(set) lazy var headerView: MediaPickerNavigationHeader = {
        let view: MediaPickerNavigationHeader = MediaPickerNavigationHeader(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        view.title = "HEADER"
        return view
    }()
    
    private(set) lazy var collectionView: UICollectionView = {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.itemSize = self.assetGridSize
        layout.sectionInset = .zero
        layout.scrollDirection = .vertical
        let view: UICollectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        view.delegate = self
        view.dataSource = self
        view.backgroundColor = .white
        return view
    }()
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

extension MediaPickerController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        self.collectionView.reloadData()
    }
}
