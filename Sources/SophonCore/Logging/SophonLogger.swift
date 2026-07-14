//
//  SophonLogger.swift
//  SophonCore
//
//  Pluggable logging: the package never links a logging framework. Consumers
//  bridge the handler to their own logger; the default routes to os.Logger.
//

import Foundation
import os

public enum SophonLogLevel: Sendable {
    case debug
    case info
    case warning
    case error
}

/// Log sink carried in client configurations. Called from the MainActor client;
/// must be safe to invoke from any isolation.
public typealias SophonLogHandler = @Sendable (_ level: SophonLogLevel, _ message: String) -> Void

public enum SophonLog {
    private static let logger = Logger(subsystem: "dev.luminoid.sophon", category: "sophon")

    /// Default handler: routes to `os.Logger` under subsystem `dev.luminoid.sophon`.
    public static let defaultHandler: SophonLogHandler = { level, message in
        switch level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
    }
}
