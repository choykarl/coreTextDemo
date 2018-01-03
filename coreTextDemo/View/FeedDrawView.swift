//
//  FeedDrawView.swift
//  coreTextDemo
//
//  Created by karl on 2017/12/29.
//  Copyright © 2017年 Karl. All rights reserved.
//

import UIKit
import CoreText

class FeedDrawView: UIView {
    
    var model: FeedModel? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(rect)
        guard let model = model else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: self.bounds.height)
        context.scaleBy(x: 1, y: -1)
        if let frame = model.drawModel.frame {
            CTFrameDraw(frame, context)
        }
        
        var drawImage: UIImage?
        for (i, imageData) in model.drawModel.imageDatas.enumerated() {
            let urlString = imageData.imageUrl
            if let image = imageData.image {
                drawImage = image
            } else if let image = YYImageCache.shared().getImageForKey(urlString) {
                drawImage = image
                model.drawModel.imageDatas[i].image = image
            } else {
                YYWebImageManager.shared().requestImage(with: URL(string: urlString)!, options: YYWebImageOptions.avoidSetImage, progress: nil, transform: nil, completion: { (image, url, _, _, error) in
                    if url.absoluteString == self.model?.drawModel.imageDatas[i].imageUrl {
                        if error == nil && image != nil {
                            let tempImage = image!.yy_imageByResize(to: imageData.imageRect.size)
                            YYImageCache.shared().setImage(tempImage!, forKey: urlString)
                            drawImage = tempImage
                            model.drawModel.imageDatas[i].image = tempImage
                            self.setNeedsDisplay()
                        }
                    }
                })
            }

            if let image = drawImage {
                context.draw(image.cgImage!, in: imageData.imageRect)
            } else {
                let placeholder = UIImage.yy_image(with: UIColor.red, size: imageData.imageRect.size)
                context.draw(placeholder!.cgImage!, in: imageData.imageRect)
            }
        }
    }
}
