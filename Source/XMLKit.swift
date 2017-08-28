//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  XMLKit.swift
//
//  Created by Dalton Cherry on 4/28/17.
//  Copyright © 2017 Vluxe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

extension String {
    var decodedText: String {
        var attrValue = self.trimmingCharacters(in: .whitespaces)
        do {
            if let data = data(using: .utf8) {
                let decoded = try NSAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue], documentAttributes: nil).string
                attrValue = decoded
            }
        } catch {}
        return attrValue
    }
}

public class Element {
    public var name: String
    public var attributes = [String: String]()
    public var text = ""
    public var children = [Element]()
    public var parent: Element?
    public var print: String {
        return doPrint(depth: 0, pretty: false)
    }
    public var prettyPrint: String {
        return doPrint(depth: 0, pretty: true)
    }
    //private value
    var end: Int = 0
    
    public init(name: String) {
        self.name = name
    }
    
    private func doPrint(depth: Int, pretty: Bool) -> String {
        var tab = ""
        if pretty {
            for _ in 0..<depth {
                tab += "\t"
            }
        }
        var str = "\(tab)<\(name)"
        for (key, value) in attributes {
            str += " \(key)=\"\(value)\""
        }
        str += ">"
        if children.count > 0 {
            for child in children {
                if pretty {
                    str += "\n"
                }
                str += "\(child.doPrint(depth: depth + 1, pretty: pretty))"
            }
            if pretty {
                str += "\n\(tab)"
            }
        } else {
            str += text
        }
        str += "</\(name)>"
        return str
    }
}

public class Parser {
    enum ElementType {
        case open
        case selfClosing
        case close
    }
    public init() {
        
    }
    
    public func parse(text: String) -> Element? {
        var rootElement: Element?
        var currentElement: Element?
        var index = 0
        var startIndex = 0
        let chars = text.characters
        for char in chars {
            //print("char: \(char)")
            if char == "<" {
                startIndex = index //handle comments?
            } else if char == ">" {
                let endIndex = index + 1 //we add 1 to include the current char
                let start = chars.index(chars.startIndex, offsetBy: startIndex)
                let end = chars.index(chars.startIndex, offsetBy: endIndex)
                let substr = text.substring(with: start..<end)
//                print("substr: \(substr)")
                let resp = parseElement(text: substr)
                resp.element.end = endIndex
                if resp.type == .close {
                    guard let current = currentElement else {return nil} //probably malformed XML.
                    if current.children.count == 0 {
                        let start = chars.index(chars.startIndex, offsetBy: current.end)
                        let end = chars.index(chars.startIndex, offsetBy: startIndex)
                        current.text = text.substring(with: start..<end).decodedText
                    }
                    currentElement = current.parent
                } else {
                    if rootElement == nil {
                        rootElement = resp.element
                    } else if let current = currentElement {
                        current.children.append(resp.element)
                    }
                    resp.element.parent = currentElement
                    if resp.type != .selfClosing {
                        currentElement = resp.element
                    }
                }
            }
            index += 1
        }
        return rootElement
    }
    
    private func parseElement(text: String) -> (element: Element, type: ElementType) {
        let chars = text.characters
        var type: ElementType = .open
        var startOffset = 1
        var endOffset = 1
        if text.hasPrefix("</") {
            startOffset = 2
            type = .close
        } else if text.hasSuffix("/>") {
            endOffset = 2
            type = .selfClosing
        }
        var end = chars.index(chars.startIndex, offsetBy: chars.count - endOffset)
        if let space = chars.index(of: " ") {
            end = space
        }
        let attrStr = text.substring(with: end..<chars.index(chars.endIndex, offsetBy: -endOffset))
        //print("attrs: \(attrStr)")
        let start = chars.index(chars.startIndex, offsetBy: startOffset)
        let name = text.substring(with: start..<end)
//        print("name: \(name)")
        let element = Element(name: name)
        parse(attributeText: attrStr, element: element)
        return (element, type)
    }
    
    private func parse(attributeText: String, element: Element) {
        let chars = attributeText.characters
        var offset = 0
        var startOffset = 0
        var eqOffset = 0
        var commaOffset = -1
        var isSingle = false
        var name: String = ""
        for char in chars {
            if char == "=" {
                eqOffset = offset
                let text = attributeText.substring(with: chars.index(chars.startIndex, offsetBy: startOffset)..<chars.index(chars.startIndex, offsetBy: eqOffset))
                //print("attr name: \(text)")
                name = text.trimmingCharacters(in: .whitespaces)
            } else if (char == "\"" && !isSingle) || char == "'" {
                if commaOffset == -1 {
                    commaOffset = offset
                    if char == "'" {
                        isSingle = true
                    }
                } else {
                    let text = attributeText.substring(with: chars.index(chars.startIndex, offsetBy: commaOffset + 1)..<chars.index(chars.startIndex, offsetBy: offset))
                    //print("attr value: \(text)")
                    commaOffset = -1
                    startOffset = offset + 1
                    isSingle = false
                    element.attributes[name] = text.decodedText
                    name = ""
                }
            }
            offset += 1
        }
    }
}
