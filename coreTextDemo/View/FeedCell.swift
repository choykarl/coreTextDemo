//
//  FeedCell.swift
//  coreTextDemo
//
//  Created by karl on 2017/12/29.
//  Copyright © 2017年 Karl. All rights reserved.
//

import UIKit

class FeedCell: UITableViewCell {
    var model: FeedModel? {
        didSet {
            drawView.model = model
        }
    }
    
    private let drawView = FeedDrawView()
    private let lineLayer = CALayer()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(drawView)
        
        lineLayer.backgroundColor = UIColor.red.cgColor
        layer.addSublayer(lineLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        drawView.frame = bounds
        lineLayer.frame = CGRect(x: 0, y: bounds.height - 0.5, width: bounds.width, height: 0.5)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
