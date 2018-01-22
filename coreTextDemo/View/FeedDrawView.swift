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
                let path = UIBezierPath(rect: imageData.imageRect)
                UIColor.green.setFill()
                path.fill()
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
            if let text = textHitTest(touchPoint) {
                let alert = UIAlertView(title: text, message: nil, delegate: nil, cancelButtonTitle: "确定")
                alert.show()
            }
        }
    }
    
    // 翻转坐标
    private func translateRect(_ fromRect: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: fromRect.minX, y: bounds.height - fromRect.height - fromRect.minY), size: fromRect.size)
    }
}

// MARK: - imageTouch
extension FeedDrawView {
    private func imageHitTest(_ hitPoint: CGPoint) -> String? {
        guard let model = model else { return nil}
        for model in model.drawModel.imageDatas {
            let imageScreenRect = translateRect(model.imageRect)
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
}

// MARK: - textTouch
extension FeedDrawView {
    private func textHitTest(_ hitPoint: CGPoint) -> String? {
        guard let model = model, let ctFrame = model.drawModel.frame else { return nil }
        
        guard let lineArray = CTFrameGetLines(ctFrame) as? [CTLine] else { return nil }
        
        var origins = [CGPoint](repeating: CGPoint.zero, count:lineArray.count)
        CTFrameGetLineOrigins(ctFrame, CFRange(location: 0, length: 0), &origins)
        
        var touchLine: CTLine?
        var touchLineOrigin: CGPoint?
        for (i, ctLine) in lineArray.enumerated() {
            // 计算出每个ctLine的rect
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, nil))
            let lineHeight = ascent + descent
            let origin = CGPoint(x: 0, y: origins[i].y - descent)
            let ctLineRect = CGRect(origin: origin, size: CGSize(width: lineWidth, height: lineHeight))
            
            // 判断当前点击的位置在不在rect内,在的话就退出循环,表示点击的是当前ctLine
            if translateRect(ctLineRect).contains(hitPoint) {
                touchLine = ctLine
                touchLineOrigin = origins[i]
                break
            }
        }
        
        if let touchLine = touchLine, let touchLineOrigin = touchLineOrigin {
            var touchSuccess = false
            // 获取点击的ctLine里的每个ctRun
            if let ctRuns = CTLineGetGlyphRuns(touchLine) as? [CTRun] {
                for ctRun in ctRuns {
                    // 计算出每个ctRun的rect
                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0
                    let width = CGFloat(CTRunGetTypographicBounds(ctRun, CFRange(location: 0, length: 0), &ascent, &descent, nil))
                    var offsetX: CGFloat = 0
                    CTLineGetOffsetForStringIndex(touchLine, CTRunGetStringRange(ctRun).location, &offsetX)
                    offsetX = offsetX + touchLineOrigin.x
                    
                    let ctRunRect = CGRect(x: offsetX, y: touchLineOrigin.y - descent, width: width, height: ascent + descent)
                    
                    // 判断当前点击的位置在不在ctRun上面
                    if translateRect(ctRunRect).contains(hitPoint) {
                        touchSuccess = true
                        break
                    }
                }
            }
            
            if touchSuccess {
                // 获取点击位置的文字在ctLine里是第几个文字
                let index = CTLineGetStringIndexForPosition(touchLine, hitPoint)
                
                // 遍历所有特殊文字的range,判断当前点击的文字在不在range内
                for textModel in model.specialTextPartModels {
                    if index >= textModel.range.location && index <= textModel.range.location + textModel.range.length {
                        return textModel.text
                    }
                }
            }
        }
        return nil
    }
}
