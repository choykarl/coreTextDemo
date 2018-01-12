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
            } else if let image = YYImageCache.shared().getImageForKey(urlString + "dd") {
                drawImage = image
                model.drawModel.imageDatas[i].image = image
            } else {
                YYWebImageManager.shared().requestImage(with: URL(string: urlString)!, options: YYWebImageOptions.avoidSetImage, progress: nil, transform: nil, completion: { (image, url, _, _, error) in
                    if url.absoluteString == self.model?.drawModel.imageDatas[i].imageUrl {
                        if error == nil && image != nil {
                            let tempImage = image!.yy_imageByResize(to: imageData.imageRect.size)
                            YYImageCache.shared().setImage(tempImage!, forKey: urlString + "dd")
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

extension FeedDrawView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let touch = touches.first else { return }
        let touchPoint = touch.location(in: self)
        
        if let imageUrlString = imageHitTest(touchPoint) {
            showImagePreview(imageUrlString)
        } else {
            
        }
    }
    
    
    private func imageHitTest(_ hitPoint: CGPoint) -> String? {
        guard let model = model else { return nil}
        for model in model.drawModel.imageDatas {
            let imageScreenRect = fetchImageScreenRect(model.imageRect)
            if imageScreenRect.contains(hitPoint) {
                return model.imageUrl
            }
        }
        return nil
    }
    
    private func showImagePreview(_ imageUrlString: String) {
        if let image = YYImageCache.shared().getImageForKey(imageUrlString) {
            let preview = ImagePreviewView(frame: UIScreen.main.bounds)
            preview.setImage(image)
            UIApplication.shared.keyWindow?.addSubview(preview)
        }
    }
    
    // 将图片坐标转为相对屏幕的坐标
    private func fetchImageScreenRect(_ inContextRect: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: inContextRect.minX, y: bounds.height - inContextRect.height - inContextRect.minY), size: inContextRect.size)
    }
}
