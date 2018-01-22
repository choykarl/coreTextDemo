//
//  ViewController.swift
//  coreTextDemo
//
//  Created by karl on 2017/12/29.
//  Copyright © 2017年 Karl. All rights reserved.
//

import UIKit
import CoreText

class ViewController: UIViewController {

    var models = [FeedModel]() {
        didSet {
            feedView.models = models
        }
    }
    var feedView: FeedView!
    override func viewDidLoad() {
        super.viewDidLoad()
        feedView = FeedView(frame: view.bounds)
        view.addSubview(feedView)
        
        self.models = createDataSource()
    }
    
    func createDataSource() -> [FeedModel] {
        guard let path = Bundle.main.path(forResource: "dataSource", ofType: "plist") else { return []}
        
        let dataSource = NSArray(contentsOfFile: path) as! [String]
        
        var models = [FeedModel]()
        
        for string in dataSource {
            let model = FeedModel()
            model.content = string
            model.drawModel.drawWidth = feedView.bounds.width
            let contentAttributedString = NSMutableAttributedString()
            
            // 解析文字
            for textPartModel in model.allTextPartModels {
                contentAttributedString.append(parseTextAttributedString(textPartModel.text, isSpecial: textPartModel.isSpecial))
            }

            // 解析图片
            for i in 0 ..< model.imagePartModels.count {
                let model = model.imagePartModels[i]
                let imageAttributedString = parseImageAttributedString(model)
                contentAttributedString.insert(imageAttributedString, at: model.range.location)
            }
            
            // 设置间距
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 10
            contentAttributedString.addAttributes([.paragraphStyle: paragraphStyle], range: NSRange(location: 0, length: contentAttributedString.string.count))
            
            let frame = parseContentAttributedString(contentAttributedString, model: model)
            model.drawModel.frame = frame
            
            // 解析图片信息
            let imageDatas = parseImageData(frame: frame)
            model.drawModel.imageDatas = imageDatas
            
            models.append(model)
        }
        return models
    }
}

extension ViewController {
    func parseTextAttributedString(_ text: String, isSpecial: Bool) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        if isSpecial {
            attributedString.addAttributes([.foregroundColor: UIColor.blue], range: NSRange(location: 0, length: text.count))
        }
        return attributedString
    }
    
    
    func parseImageAttributedString(_ partModel: ImagePartModel) -> NSMutableAttributedString {
        let char: UniChar = 0xFFFC
        let content = String(repeating: Character(UnicodeScalar(char)!), count: partModel.range.length)
        let space = NSMutableAttributedString(string: content)
        
        /*
         这里字体用0.001主要是为了设置一个极其小的字体来让这个字符串的显示长度达到最小.
         space在这里其实是一个挺长的字符串"[{width:xx,height:xx,url:xxxx...}]"
         如果这个字符串的长度大于了图片的宽度,会显示出多余的空白,所以在这里把字体设置的极小,让字符串的长度不至于比图片还要宽.
         这里没有把space设置成长度为1,主要是为了space在插入到contentAttributedString里不需要额外的做插入位置索引的计算.
         */
        space.addAttributes([NSAttributedStringKey.font : UIFont.systemFont(ofSize: 0.001)], range: NSRange(location: 0, length: partModel.range.length))
        var callbaces = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { (_) in
        }, getAscent: { (pointer) -> CGFloat in
            let height = pointer.load(as: ImageDataModel.self).imageRect.size.height
            return height
        }, getDescent: { (_) -> CGFloat in
            return 0
        }) { (pointer) -> CGFloat in
            let width = pointer.load(as: ImageDataModel.self).imageRect.size.width
            return width
        }
        let delegate = CTRunDelegateCreate(&callbaces, &partModel.imageData)
        
        CFAttributedStringSetAttribute(space, CFRange(location: 0, length: 1), kCTRunDelegateAttributeName, delegate)
        return space
    }
    
    func parseContentAttributedString(_ attributedString: NSMutableAttributedString, model: FeedModel) -> CTFrame {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // 计算画布大小
        let drawPathWidth = model.drawModel.drawWidth
        let drawPathHeight = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil, CGSize(width: drawPathWidth, height: CGFloat(MAXFLOAT)), nil).height
        model.drawModel.drawHeight = drawPathHeight
        
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: drawPathWidth, height: drawPathHeight))
        
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        
        return frame
    }
    
    // image的位置和名字
    func parseImageData(frame: CTFrame) -> [ImageDataModel] {
        var models = [ImageDataModel]()
        
        guard let lineArray = CTFrameGetLines(frame) as? [CTLine] else { return models }
        var origins = [CGPoint](repeating: CGPoint.zero, count:lineArray.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        for (i, line) in lineArray.enumerated() {
            let linePoint = origins[i]
            guard let runArray = CTLineGetGlyphRuns(line) as? [CTRun] else { continue }
            for run in runArray {
                let attributes = CTRunGetAttributes(run) as Dictionary
                guard let delegate = attributes[kCTRunDelegateAttributeName] else {
                    continue
                }
                
                // 获取代理绑定的数据
                let imageUrl = CTRunDelegateGetRefCon(delegate as! CTRunDelegate).load(as: ImageDataModel.self).imageUrl
                
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                
                let width = CGFloat(CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), &ascent, &descent, nil))
                let height = ascent + descent
                var offsetX: CGFloat = 0
                CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, &offsetX)
                let x = offsetX + linePoint.x
                let y = linePoint.y - descent
                
                let bounds = CGRect(x: x, y: y, width: width, height: height)
                
                let path = CTFrameGetPath(frame)
                let pathRect = path.boundingBox
                let imageBounds = bounds.offsetBy(dx: pathRect.minX, dy: pathRect.minY)
                
                let model = ImageDataModel()
                model.imageUrl = imageUrl
                model.imageRect = imageBounds
                models.append(model)
            }
        }
        return models
    }
}

