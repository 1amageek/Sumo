//
//  FAMImagePickerNavigationHeader.swift
//  Sumo
//
//  Created by 1amageek on 2017/04/03.
//  Copyright © 2017年 Stamp Inc. All rights reserved.
//

import UIKit

class FAMImagePickerNavigationHeader: UIView {
    
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
    
    fileprivate(set) lazy var titleLabel: UILabel = {
        var titleLabel: UILabel = UILabel(frame: .zero)
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 15)
        return titleLabel
    }()
    
    fileprivate(set) lazy var detailLabel: UILabel = {
        var detailLabel: UILabel = UILabel(frame: .zero)
        detailLabel.numberOfLines = 1
        detailLabel.font = UIFont.systemFont(ofSize: 10)
        return detailLabel
    }()
    
}
