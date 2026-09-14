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
    /// Payload-level detail (raw model output on a decode failure). The default
    /// handler logs it privately; the other levels carry fixed-format status
    /// lines and log publicly.
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
    /// `.debug` lines may echo model output that describes the user's prompt or
    /// photos, so they are logged privately; the rest are fixed status lines.
    public static let defaultHandler: SophonLogHandler = { level, message in
        switch level {
        case .debug: logger.debug("\(message, privacy: .private)")
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
    }
}
