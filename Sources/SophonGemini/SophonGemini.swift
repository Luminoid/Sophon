//
//  SophonGemini.swift
//  SophonGemini
//
//  Re-exports SophonCore: the Gemini-era names are typealiases onto Core types
//  whose members (schema cases, message roles, model-store `current` /
//  `select`, the configuration's key helpers) live in Core protocol
//  extensions. Under Swift 6.2's member-import visibility a file that only
//  imports SophonGemini would otherwise not see them, which would break every
//  consumer written against 0.1 / 0.2.
//

@_exported import SophonCore
