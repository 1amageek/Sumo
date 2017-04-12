//
//  MediaPickerCell.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/03.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import UIKit
import Photos

class MediaPickerCell: UICollectionViewCell {

    var id: String?
    var imageRequestID: PHImageRequestID?
    var item: Sumo.Item?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.white
        self.backgroundView = self.imageView
        self.contentView.addSubview(videoLengthLabel)
        self.layer.borderWidth = 0
        self.layer.borderColor = UIColor.blue.cgColor
        self.clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        self.imageView.animationImages = nil
        self.videoLength = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.bounds
        self.videoLengthLabel.sizeToFit()
        self.videoLengthLabel.frame = CGRect(x: self.bounds.width - self.videoLengthLabel.bounds.width - 6,
                                             y: self.bounds.height - self.videoLengthLabel.bounds.height - 2,
                                             width: self.videoLengthLabel.bounds.width,
                                             height: self.videoLengthLabel.bounds.height)
    }
    
    override var isSelected: Bool {
        didSet {
            self.layer.borderWidth = isSelected ? 6 : 0
        }
    }
    
    var canUpload: Bool = true {
        didSet {
            self.imageView.alpha = canUpload ? self.imageView.alpha : 0.65
        }
    }
    
    func cancel() {
        
    }
    
    // MARK: - Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.scaleAnimationToShrink(shrink: true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.scaleAnimationToShrink(shrink: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.scaleAnimationToShrink(shrink: false)
    }
    
    func scaleAnimationToShrink(shrink: Bool) {
        UIView.animate(withDuration: 0.18) {
            if shrink {
                self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            } else {
                self.transform = .identity
            }
        }
    }
    
    // MARK: - element
    
    var image: UIImage? {
        didSet {
            self.imageView.image = image
            self.imageView.setNeedsDisplay()
        }
    }
    
    var animationImages: [UIImage]? {
        didSet {
            self.imageView.animationImages = animationImages
        }
    }
    
    private(set) lazy var imageView: UIImageView = {
        let view: UIImageView = UIImageView(frame: .zero)
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    var videoLength: String? {
        didSet {
            self.videoLengthLabel.text = videoLength
            self.setNeedsLayout()
        }
    }
    
    private(set) lazy var videoLengthLabel: UILabel = {
        let label: UILabel = UILabel(frame: .zero)
        label.numberOfLines = 1
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
}
