//
//  Log.swift
//  Typenary
//
//  Created by Do Duc on 28/07/2018.
//  Copyright © 2018 Do Duc. All rights reserved.
//

/// Based on Sauvik Dolui's blog 👇
/// https://medium.com/@sauvik_dolui/developing-a-tiny-logger-in-swift-7221751628e6

import Foundation

typealias FileDetails = (path: String, line: Int, funcName: String)

enum LogLevel: String {
    case verbose
    case debug
    case info
    case warning
    case error
    case severe
}

extension LogLevel {
    var description: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "👀"
        case .info: return "[ℹ️]"
        case .warning: return "[⚠️]"
        case .error: return "[‼️]"
        case .severe: return "[🔥]"
        }
    }
    
    var piority: Int {
        switch self {
        case .verbose: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .severe: return 5
        }
    }
}

func print(_ object: Any) {
    // Only allowing in DEBUG mode
    #if DEBUG
    Swift.print(object)
    #endif
}

class Log {
    private static func fileName(path: String) -> String {
        guard let name = path.components(separatedBy: "/").last else {
            return "No path"
        }
        
        return name
    }
    
    private class func log(level: LogLevel, content: Any, fileDetails: FileDetails) {

        print("[\(DateFormatterHelper.shared.formatFullTimeString(from: Date()))] \(level.description) [\(fileName(path: fileDetails.path)): line \(fileDetails.line)]: \(fileDetails.funcName) -> \(content)")
    }
    
    class func error(_ content: Any, fileDetails: FileDetails = (path: #file, line: #line, funcName: #function)) {
        log(level: .error, content: content, fileDetails: fileDetails)
    }
    
    class func info(_ content: Any, fileDetails: FileDetails = (path: #file, line: #line, funcName: #function)) {
        log(level: .info, content: content, fileDetails: fileDetails)
    }
    
    class func debug(_ content: Any, fileDetails: FileDetails = (path: #file, line: #line, funcName: #function)) {
        log(level: .debug, content: content, fileDetails: fileDetails)
    }
    
    class func verbose(_ content: Any, fileDetails: FileDetails = (path: #file, line: #line, funcName: #function)) {
        log(level: .verbose, content: content, fileDetails: fileDetails)
    }
    
    class func warning(_ content: Any, fileDetails: FileDetails = (path: #file, line: #line, funcName: #function)) {
        log(level: .warning, content: content, fileDetails: fileDetails)
    }
    
    class func severe(_ content: Any, fileDetails: FileDetails = (path: #file, line: #line, funcName: #function)) {
        log(level: .severe, content: content, fileDetails: fileDetails)
    }
}
