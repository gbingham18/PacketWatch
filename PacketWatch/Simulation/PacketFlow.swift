//
//  PacketFlow.swift
//  PacketWatch
//
//  Created by Grant Bingham on 2/22/26.
//

import Foundation

/// Mimics NEPacketTunnelFlow. Delivers batches of packets via a callback,
/// just like the real readPacketObjects().
class PacketFlow {
    private var generator: PacketGenerator?
    private var isRunning = false
    private var timer: Timer?
    
    /// Start delivering packets. Calls the handler with a batch every `interval` seconds.
    func startGenerating(interval: TimeInterval = 1.0, handler: @escaping ([Packet]) -> Void) {
        let gen = PacketGenerator()
        self.generator = gen
        self.isRunning = true
        print("Generator Created")
        
        // Simulate async packet delivery on a timer.
        // Must be added to RunLoop.main explicitly so it fires when called from async contexts.
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else {
                print("Outer early return")
                return
            }
            let batch = gen.nextBatch()
            print("Next Batch")
            if !batch.isEmpty {
                handler(batch)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Mimics writePacketObjects — in the mock, this is a no-op.
    func writePacketObjects(_ packets: [Packet]) {
        // In real provider, this reinjects packets into the network stack.
        // Here we just count them for verification.
    }
}
