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
    weak var context: CGContext?
    private var selectedRects = [CGRect]()
    private var selectedEnd = false
    
    override func draw(_ rect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(rect)
        guard let model = model else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        self.context = context
        
        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: self.bounds.height)
        context.scaleBy(x: 1, y: -1)
        
        drawTouchBackground()
        
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
    
    private func drawTouchBackground() {
        for (i, r) in selectedRects.enumerated() {
            var path: UIBezierPath!
            if selectedRects.count == 1 {
                path = UIBezierPath(roundedRect: r, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: r.height / 2, height: r.height / 2))
            } else {
                if i == 0 {
                    path = UIBezierPath(roundedRect: r, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: r.height / 2, height: r.height / 2))
                } else if i == selectedRects.count - 1 {
                    path = UIBezierPath(roundedRect: r, byRoundingCorners: [.topRight, .bottomRight], cornerRadii: CGSize(width: r.height / 2, height: r.height / 2))
                } else {
                    path = UIBezierPath(rect: r)
                }
            }
            if selectedEnd {
                UIColor.clear.setFill()
            } else {
                UIColor.red.setFill()
            }
            path.fill()
        }
        if selectedEnd {
            selectedRects.removeAll()
        }
    }
}

extension FeedDrawView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedRects.removeAll()
        guard let touch = touches.first else { return }
        let touchPoint = touch.location(in: self)
        
        if let imageUrlString = imageHitTest(touchPoint) {
            showImagePreview(imageUrlString)
        } else {
            if let text = textHitTest(touchPoint) {
                print("touch = \(text)")
//                let alert = UIAlertView(title: text, message: nil, delegate: nil, cancelButtonTitle: "确定")
//                alert.show()
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedEnd = true
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedEnd = true
        setNeedsDisplay()
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
        
        var tempTouchLine: CTLine?
        var tempTouchLineOrigin: CGPoint?
        for (i, ctLine) in lineArray.enumerated() {
            // 计算出每个ctLine的rect
            let ctLineRect = getLineRect(ctLine, ctLineOrigin: origins[i])
            // 判断当前点击的位置在不在rect内,在的话就退出循环,表示点击的是当前ctLine
            if translateRect(ctLineRect).contains(hitPoint) {
                tempTouchLine = ctLine
                tempTouchLineOrigin = origins[i]
                break
            }
        }
        
        guard let touchLine = tempTouchLine, let touchLineOrigin = tempTouchLineOrigin else {
            return nil
        }
        
        guard let _ = getTouchRun(touchLine, touchLineOrigin: touchLineOrigin, hitPoint: hitPoint) else {
            return nil
        }
        
        // 获取点击位置的文字在ctLine里是第几个文字
        let index = CTLineGetStringIndexForPosition(touchLine, hitPoint)
        guard let touchText = getSpecialText(model, index: index) else {
            return nil
        }
        
        // 当前点击的特殊文字的range
        let touchTextRange = getSpecialTextRange(model, index: index)
        
        for (i, ctLine) in lineArray.enumerated() {
            if let ctRuns = CTLineGetGlyphRuns(ctLine) as? [CTRun] {
                var rects = [CGRect]()
                for ctRun in ctRuns {
                    let range = CTRunGetStringRange(ctRun)
                    // 这个ctRun的的range是否在点击特殊文字的range上
                    guard touchTextRange.contains(range.location) else {
                        continue
                    }
                    
                    // 获得当前ctRun的bounds
                    var rect = CTRunGetImageBounds(ctRun, context, CFRange(location: 0, length: 0))
                    // y需要加上当前line的y
                    rect.origin.y += origins[i].y
                    rects.append(rect)
                }
                if rects.count > 0 {
                    // 每个ctRun的高度不一样,这里找出最高的ctRun
                    let maxRect = rects.sorted(by: {$0.height > $1.height}).first!
                    // 将所有相邻的rect连在一起
                    let touchLineRect = CGRect(x: rects.first!.minX, y: maxRect.minY, width: rects.last!.maxX - rects.first!.minX, height: maxRect.height)
                    selectedRects.append(touchLineRect)
                }
            }
        }
        if selectedRects.count > 0 {
            selectedEnd = false
            setNeedsDisplay()
        }
        
        return touchText
    }
}


extension FeedDrawView {
    private func getTouchRun(_ touchLine: CTLine, touchLineOrigin: CGPoint, hitPoint: CGPoint) -> CTRun? {
        var touchRun: CTRun?
        // 获取点击的ctLine里的每个ctRun
        if let ctRuns = CTLineGetGlyphRuns(touchLine) as? [CTRun] {
            for ctRun in ctRuns {
                // 计算出每个ctRun的rect
                let ctRunRect = getRunRect(ctRun, ctLine: touchLine, ctLineOrigin: touchLineOrigin)
                // 判断当前点击的位置在不在ctRun上面
                if translateRect(ctRunRect).contains(hitPoint) {
                    touchRun = ctRun
                    break
                }
            }
        }
        return touchRun
    }
    
    private func getLineRect(_ ctLine: CTLine, ctLineOrigin origin: CGPoint) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, nil))
        let lineHeight = ascent + descent
        let origin = CGPoint(x: 0, y: origin.y - descent)
        let ctLineRect = CGRect(origin: origin, size: CGSize(width: lineWidth, height: lineHeight))
        return ctLineRect
    }
    
    private func getRunRect(_ ctRun: CTRun, ctLine: CTLine, ctLineOrigin origin: CGPoint) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTRunGetTypographicBounds(ctRun, CFRange(location: 0, length: 0), &ascent, &descent, nil))
        var offsetX: CGFloat = 0
        CTLineGetOffsetForStringIndex(ctLine, CTRunGetStringRange(ctRun).location, &offsetX)
        offsetX = offsetX + origin.x
        
        let ctRunRect = CGRect(x: offsetX, y: origin.y - descent, width: width, height: ascent + descent)
        return ctRunRect
    }
    
    private func getSpecialText(_ model: FeedModel, index: CFIndex) -> String? {
        // 遍历所有特殊文字的range,判断当前点击的文字在不在range内
        for textModel in model.specialTextPartModels {
            if index >= textModel.range.location && index <= textModel.range.location + textModel.range.length {
                return textModel.text
            }
        }
        return nil
    }
    
    private func getSpecialTextRange(_ model: FeedModel, index: CFIndex) -> NSRange {
        var range = NSRange(location: 0, length: 0)
        for textModel in model.specialTextPartModels {
            if index >= textModel.range.location && index <= textModel.range.location + textModel.range.length {
                range = textModel.range
            }
        }
        return range
    }
}
