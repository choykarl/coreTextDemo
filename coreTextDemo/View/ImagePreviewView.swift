//
//  ImagePreviewView.swift
//  coreTextDemo
//
//  Created by karl on 2018/01/12.
//  Copyright © 2018年 Karl. All rights reserved.
//

import UIKit

class ImagePreviewView: UIView {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
    }
    
    func setImage(_ image: UIImage) {
        imageView.frame = CGRect(origin: CGPoint(x: (bounds.width - image.size.width) / 2, y: (bounds.height - image.size.height) / 2), size: image.size)
        imageView.image = image
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeFromSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
