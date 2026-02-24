//
//  DeterministicPRNG.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 17/02/26.
//


import Foundation

struct DeterministicPRNG {
    private var state: UInt64
    
    private let multiplier: UInt64 = 6364136223846793005
    private let increment: UInt64 = 1442695040888963407
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* multiplier &+ increment
        return state
    }
    
    mutating func next(upperBound: Int) -> Int {
        return Int(next() % UInt64(upperBound))
    }
}
