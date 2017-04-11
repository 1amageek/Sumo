//
//  MediaPickerHeader.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/03.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import UIKit

class MediaPickerHeader: UICollectionViewCell {
    
    let contentInset: UIEdgeInsets = UIEdgeInsets(top: 24, left: 8, bottom: 12, right: 8)
    
    weak var delegate: MediaPickerHeaderDelegate?
    
    var section: Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(selectButton)
        self.addSubview(titleLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var title: String? {
        didSet {
            self.titleLabel.text = title
            self.setNeedsLayout()
        }
    }
    
    private(set) lazy var titleLabel: UILabel = {
        let titleLabel: UILabel = UILabel(frame: .zero)
        titleLabel.numberOfLines = 1
        titleLabel.textColor = UIColor.black
        titleLabel.font = UIFont.systemFont(ofSize: 15)
        return titleLabel
    }()
    
    private(set) lazy var selectButton: UIButton = {
        let button: UIButton = UIButton(type: UIButtonType.system)
        button.setTitle("Select", for: .normal)
        return button
    }()
    
    func tapped() {
        if self.isSelected {
            self.isSelected = !self.isSelected
            self.delegate?.header(header: self, didSelected: self.isSelected)
        } else {
            if (self.delegate?.shouldSelectHeader(header: self) ?? false) {
                self.isSelected = !self.isSelected
                self.delegate?.header(header: self, didSelected: self.isSelected)
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            self.selectButton.backgroundColor = isSelected ? UIColor.white : UIColor.white
            self.setNeedsDisplay()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        _ = calculateSize()
    }
    
    func calculateSize() -> CGSize {
        selectButton.sizeToFit()
        titleLabel.sizeToFit()
        self.selectButton.frame = CGRect(x: self.bounds.width - contentInset.right - selectButton.bounds.width,
                                         y: contentInset.top,
                                         width: selectButton.bounds.width,
                                         height: selectButton.bounds.height)
        let heigth: CGFloat = self.selectButton.frame.maxY + contentInset.bottom
        self.titleLabel.frame = CGRect(x: contentInset.left,
                                       y: heigth - contentInset.bottom - titleLabel.bounds.height,
                                       width: titleLabel.bounds.width,
                                       height: titleLabel.bounds.height)
        return CGSize(width: self.bounds.width, height: heigth)
    }
    
}

protocol MediaPickerHeaderDelegate: class {
    func shouldSelectHeader(header: MediaPickerHeader) -> Bool
    func header(header: MediaPickerHeader, didSelected selected: Bool)
}
