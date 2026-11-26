import AVFoundation
import Foundation
import Testing

@testable import PendantKit

@Suite struct OpusDecoderTests {
  /// Opus frames of one second of a 440 Hz tone, encoded like the pendant does.
  private func encodedTone() throws -> [Data] {
    let pcm = OpusDecoder.pcmFormat
    let encoder = try #require(AVAudioConverter(from: pcm, to: OpusDecoder.opusFormat))
    encoder.bitRate = 32000
    let input = try #require(AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: 16000))
    input.frameLength = 16000
    for i in 0..<16000 {
      input.int16ChannelData![0][i] = Int16(8000 * sin(2 * Double.pi * 440 * Double(i) / 16000))
    }
    var frames: [Data] = []
    var fed = false
    while true {
      let out = AVAudioCompressedBuffer(
        format: OpusDecoder.opusFormat, packetCapacity: 8, maximumPacketSize: 1500)
      let status = encoder.convert(to: out, error: nil) { _, inputStatus in
        if fed {
          inputStatus.pointee = .endOfStream
          return nil
        }
        fed = true
        inputStatus.pointee = .haveData
        return input
      }
      for p in 0..<Int(out.packetCount) {
        let d = out.packetDescriptions![p]
        frames.append(
          Data(bytes: out.data.advanced(by: Int(d.mStartOffset)), count: Int(d.mDataByteSize)))
      }
      if status != .haveData || out.packetCount == 0 { break }
    }
    return frames
  }

  @Test func decodesEachFrameTo20MillisecondsOfPCM() throws {
    let frames = try encodedTone()
    let decoder = try #require(OpusDecoder())
    let pcm = frames.map(decoder.decode)
    #expect(frames.count >= 50)
    #expect(pcm.dropFirst().allSatisfy { $0.count == 640 })
  }

  @Test func returnsNothingForAnEmptyFrame() throws {
    let decoder = try #require(OpusDecoder())
    #expect(decoder.decode(Data()).isEmpty)
  }
}
