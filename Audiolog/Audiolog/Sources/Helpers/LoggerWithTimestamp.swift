//
//  LoggerWithTimestamp.swift
//  colight
//
//  Created by Sean Cho on 8/19/25.
//

import os
import SwiftUI

struct LoggerWithTimestamp {
    private let logger = Logger()

    func log(_ message: String) {
        let timestamp = Date().formatted("yyyy-MM-dd HH:mm:ss")
        logger.log("[\(timestamp)] \(message)")
    }
    func info(_ message: String) {
        let timestamp = Date().formatted("yyyy-MM-dd HH:mm:ss")
        logger.info("[\(timestamp)] \(message)")
    }
    func error(_ message: String) {
        let timestamp = Date().formatted("yyyy-MM-dd HH:mm:ss")
        logger.error("[\(timestamp)] \(message)")
    }
    func debug(_ message: String) {
        let timestamp = Date().formatted("yyyy-MM-dd HH:mm:ss")
        logger.debug("[\(timestamp)] \(message)")
    }
}
