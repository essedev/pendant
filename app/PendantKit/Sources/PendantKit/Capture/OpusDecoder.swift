import AVFoundation

/// Decodes the pendant's Opus frames into the PCM that `audio_stream` expects.
///
/// Uses the system Opus codec (AudioToolbox), so the app needs no third-party library. Output
/// is signed 16-bit little-endian, mono, 16 kHz (ARCHITECTURE, "Server contract"). One
/// decoder per conversation: Opus keeps state between frames.
public final class OpusDecoder {
  /// The PCM format sent to Nexus.
  public static let pcmFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

  /// The Opus format of the pendant: 16 kHz mono, 20 ms frames (`config.h`, `codec.c`).
  public static let opusFormat: AVAudioFormat = {
    var description = AudioStreamBasicDescription(
      mSampleRate: 16000, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0,
      mFramesPerPacket: 320, mBytesPerFrame: 0, mChannelsPerFrame: 1, mBitsPerChannel: 0,
      mReserved: 0)
    return AVAudioFormat(streamDescription: &description)!
  }()

  private let converter: AVAudioConverter

  /// A decoder, or nil when the system has no Opus decoder.
  public init?() {
    guard let converter = AVAudioConverter(from: Self.opusFormat, to: Self.pcmFormat) else {
      return nil
    }
    self.converter = converter
  }

  /// The PCM of one Opus frame; empty when the frame does not decode.
  public func decode(_ frame: Data) -> Data {
    guard !frame.isEmpty else { return Data() }
    let compressed = AVAudioCompressedBuffer(
      format: Self.opusFormat, packetCapacity: 1, maximumPacketSize: frame.count)
    frame.withUnsafeBytes {
      compressed.data.copyMemory(from: $0.baseAddress!, byteCount: frame.count)
    }
    compressed.packetDescriptions![0] = AudioStreamPacketDescription(
      mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(frame.count))
    compressed.packetCount = 1
    compressed.byteLength = UInt32(frame.count)

    // 960 samples covers the longest Opus frame at 16 kHz (60 ms); the pendant sends 320.
    guard let output = AVAudioPCMBuffer(pcmFormat: Self.pcmFormat, frameCapacity: 960) else {
      return Data()
    }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      if supplied {
        inputStatus.pointee = .noDataNow
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return compressed
    }
    guard status != .error, error == nil, let samples = output.int16ChannelData else {
      return Data()
    }
    return Data(bytes: samples[0], count: Int(output.frameLength) * 2)
  }
}
