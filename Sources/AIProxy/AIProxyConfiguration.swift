//
//  AIProxyConfiguration.swift
//  AIProxy
//
//  Created by Lou Zell on 7/31/25.
//
//  This fork removes the hosted-proxy backend entirely. The configuration
//  struct is reduced to logging knobs that the DirectService path still uses.
//

nonisolated struct AIProxyConfiguration {
    let printRequestBodies: Bool
    let printResponseBodies: Bool
}
