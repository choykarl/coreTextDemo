//
//  RegularExpressionTool.swift
//  coreTextDemo
//
//  Created by karl on 2017/12/29.
//  Copyright © 2017年 Karl. All rights reserved.
//

import Foundation
enum RegularExpression: Error {
    case initError(String)
}

extension NSRegularExpression {
    // 用匹配结果分割字符串
    func enumerateSeparatedByRegex(in string: String, range: NSRange, using block: (Range<String.Index>, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) {
        var rangeArray = [NSRange]()
        enumerateMatches(in: string, range: range) { (result, _, _) in
            guard let result = result, result.range.length > 0 else { return }
            rangeArray.append(result.range)
        }
        var tempRange = NSRange(location: 0, length: 0)
        for (i, range) in rangeArray.enumerated() {
            if i == 0 {
                if range.location != 0 {
                    tempRange = NSRange(location: 0, length: rangeArray[i].location)
                }
            } else {
                let previousRange = rangeArray[i - 1]
                let tempRangeLocation = previousRange.location + previousRange.length
                tempRange = NSRange(location: tempRangeLocation, length: range.location - tempRangeLocation)
            }
            
            var stop = ObjCBool(false)
            
            let stringIndexRange = Range(tempRange, in: string) ?? string.index(string.startIndex, offsetBy: tempRange.location) ..< string.index(string.startIndex, offsetBy: tempRange.location + tempRange.length)
            
            block(stringIndexRange, &stop)
            if stop.boolValue == true {
                return
            }
        }
    }
}

extension String {
    func enumerateMatches(pattern: String, range: NSRange, using block: (Range<String.Index>, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) throws {
        
        guard let regular = try? NSRegularExpression(pattern: pattern) else {
            throw RegularExpression.initError("RegularExpression 初始化失败")
        }
        
        regular.enumerateMatches(in: self, range: range) { (result, flags, stop) in
            guard let result = result, result.range.length > 0 else { return }
            var stopFlag = ObjCBool(false)
            
            let range = Range(result.range, in: self) ?? self.index(self.startIndex, offsetBy: result.range.location) ..< self.index(self.startIndex, offsetBy: result.range.location + result.range.length)
            block(range, &stopFlag)
            if stopFlag.boolValue {
                stop.pointee = true
            }
        }
    }
    
    func enumerateSeparatedByRegex(pattern: String, range: NSRange, using block: (Range<String.Index>, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) throws  {
        guard let regular = try? NSRegularExpression(pattern: pattern) else {
            throw RegularExpression.initError("RegularExpression 初始化失败")
        }
        regular.enumerateSeparatedByRegex(in: self, range: range, using: block)
    }
}

