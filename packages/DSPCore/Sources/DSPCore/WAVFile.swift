import Foundation

public enum WAVError: Error, CustomStringConvertible, Sendable {
    case invalidFile(String)
    case unsupportedFormat(audioFormat: UInt16, bitsPerSample: UInt16, channels: UInt16)

    public var description: String {
        switch self {
        case let .invalidFile(reason): "Invalid WAV file: \(reason)"
        case let .unsupportedFormat(format, bits, channels): "Unsupported WAV format \(format), \(bits)-bit, \(channels) channels. Use mono/stereo PCM16, PCM24, PCM32, or Float32."
        }
    }
}

public enum WAVFile {
    public static func read(url: URL) throws -> AudioBuffer {
        try read(data: Data(contentsOf: url))
    }

    /// Decodes an already-validated byte snapshot. This lets callers bind
    /// metadata validation and any later upload to the exact same immutable
    /// bytes instead of reopening a filesystem path between checks.
    public static func read(data: Data) throws -> AudioBuffer {
        guard data.count >= 44, String(decoding: data[0..<4], as: UTF8.self) == "RIFF", String(decoding: data[8..<12], as: UTF8.self) == "WAVE" else {
            throw WAVError.invalidFile("Missing RIFF/WAVE header")
        }
        var offset = 12
        var format: (audio: UInt16, channels: UInt16, sampleRate: UInt32, bits: UInt16)?
        var audioData: Data?
        while offset + 8 <= data.count {
            let id = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
            let size = Int(readUInt32(data, offset + 4))
            let start = offset + 8, end = start + size
            guard end <= data.count else { throw WAVError.invalidFile("Chunk exceeds file length") }
            if id == "fmt " {
                guard size >= 16 else { throw WAVError.invalidFile("Short fmt chunk") }
                var audioFormat = readUInt16(data, start)
                if audioFormat == 0xfffe, size >= 40 {
                    audioFormat = readUInt16(data, start + 24)
                }
                format = (audioFormat, readUInt16(data, start + 2), readUInt32(data, start + 4), readUInt16(data, start + 14))
            } else if id == "data" { audioData = data.subdata(in: start..<end) }
            offset = end + (size % 2)
        }
        guard let format, let audioData else { throw WAVError.invalidFile("Missing fmt or data chunk") }
        guard (8_000...768_000).contains(format.sampleRate) else {
            throw WAVError.invalidFile("Sample rate must be between 8 kHz and 768 kHz")
        }
        let supportedIntegerPCM = format.audio == 1 && [16, 24, 32].contains(format.bits)
        guard (format.channels == 1 || format.channels == 2), supportedIntegerPCM || (format.audio == 3 && format.bits == 32) else {
            throw WAVError.unsupportedFormat(audioFormat: format.audio, bitsPerSample: format.bits, channels: format.channels)
        }
        let bytesPerSample = Int(format.bits / 8), channelCount = Int(format.channels)
        guard audioData.count % (bytesPerSample * channelCount) == 0 else { throw WAVError.invalidFile("Audio data is not frame aligned") }
        let frameCount = audioData.count / (bytesPerSample * channelCount)
        var channels = Array(repeating: Array(repeating: Float.zero, count: frameCount), count: channelCount)
        audioData.withUnsafeBytes { raw in
            for frame in 0..<frameCount { for channel in 0..<channelCount {
                let byteOffset = (frame * channelCount + channel) * bytesPerSample
                if format.audio == 1 && format.bits == 16 {
                    let value = Int16(bitPattern: UInt16(raw[byteOffset]) | UInt16(raw[byteOffset + 1]) << 8)
                    channels[channel][frame] = Float(value) / 32_768
                } else if format.audio == 1 && format.bits == 24 {
                    var bits = Int32(UInt32(raw[byteOffset]) | UInt32(raw[byteOffset + 1]) << 8 | UInt32(raw[byteOffset + 2]) << 16)
                    if bits & 0x0080_0000 != 0 { bits |= ~0x00ff_ffff }
                    channels[channel][frame] = Float(bits) / 8_388_608
                } else if format.audio == 1 && format.bits == 32 {
                    let bits = UInt32(raw[byteOffset]) | UInt32(raw[byteOffset + 1]) << 8 | UInt32(raw[byteOffset + 2]) << 16 | UInt32(raw[byteOffset + 3]) << 24
                    channels[channel][frame] = Float(Int32(bitPattern: bits)) / 2_147_483_648
                } else {
                    let bits = UInt32(raw[byteOffset]) | UInt32(raw[byteOffset + 1]) << 8 | UInt32(raw[byteOffset + 2]) << 16 | UInt32(raw[byteOffset + 3]) << 24
                    let value = Float(bitPattern: bits)
                    channels[channel][frame] = value.isFinite ? value : 0
                }
            }}
        }
        return AudioBuffer(channels: channels, sampleRate: Double(format.sampleRate))
    }

    public static func writeFloat32(_ buffer: AudioBuffer, url: URL) throws {
        let (sampleRate, dataSize) = try validatedWriteFormat(buffer, bytesPerSample: 4)
        var output = Data()
        output.append(contentsOf: Array("RIFF".utf8)); appendUInt32(UInt32(36 + dataSize), to: &output)
        output.append(contentsOf: Array("WAVEfmt ".utf8)); appendUInt32(16, to: &output)
        appendUInt16(3, to: &output); appendUInt16(UInt16(buffer.channelCount), to: &output)
        appendUInt32(sampleRate, to: &output)
        appendUInt32(sampleRate * UInt32(buffer.channelCount) * 4, to: &output)
        appendUInt16(UInt16(buffer.channelCount * 4), to: &output); appendUInt16(32, to: &output)
        output.append(contentsOf: Array("data".utf8)); appendUInt32(UInt32(dataSize), to: &output)
        for frame in 0..<buffer.frameCount { for channel in 0..<buffer.channelCount { appendUInt32(buffer.channels[channel][frame].bitPattern, to: &output) } }
        try output.write(to: url, options: .atomic)
    }

    public static func writePCM24(_ buffer: AudioBuffer, url: URL) throws {
        let bytesPerSample = 3
        let (sampleRate, dataSize) = try validatedWriteFormat(buffer, bytesPerSample: bytesPerSample)
        var output = Data()
        output.append(contentsOf: Array("RIFF".utf8)); appendUInt32(UInt32(36 + dataSize), to: &output)
        output.append(contentsOf: Array("WAVEfmt ".utf8)); appendUInt32(16, to: &output)
        appendUInt16(1, to: &output); appendUInt16(UInt16(buffer.channelCount), to: &output)
        appendUInt32(sampleRate, to: &output)
        appendUInt32(sampleRate * UInt32(buffer.channelCount * bytesPerSample), to: &output)
        appendUInt16(UInt16(buffer.channelCount * bytesPerSample), to: &output); appendUInt16(24, to: &output)
        output.append(contentsOf: Array("data".utf8)); appendUInt32(UInt32(dataSize), to: &output)
        for frame in 0..<buffer.frameCount { for channel in 0..<buffer.channelCount {
            let sample = min(max(Double(buffer.channels[channel][frame]), -1), 1 - 1 / 8_388_608)
            let value = Int32((sample * 8_388_608).rounded())
            let bits = UInt32(bitPattern: value)
            output.append(UInt8(bits & 0xff)); output.append(UInt8((bits >> 8) & 0xff)); output.append(UInt8((bits >> 16) & 0xff))
        }}
        try output.write(to: url, options: .atomic)
    }

    private static func validatedWriteFormat(
        _ buffer: AudioBuffer,
        bytesPerSample: Int
    ) throws -> (sampleRate: UInt32, dataSize: Int) {
        guard buffer.channelCount == 1 || buffer.channelCount == 2,
              buffer.sampleRate.isFinite,
              (8_000...768_000).contains(buffer.sampleRate),
              buffer.sampleRate.rounded(.towardZero) == buffer.sampleRate else {
            throw WAVError.invalidFile("WAV output requires mono/stereo audio at an integer sample rate between 8 kHz and 768 kHz")
        }
        let (sampleCount, sampleCountOverflow) = buffer.frameCount.multipliedReportingOverflow(
            by: buffer.channelCount
        )
        let (dataSize, dataSizeOverflow) = sampleCount.multipliedReportingOverflow(by: bytesPerSample)
        guard !sampleCountOverflow,
              !dataSizeOverflow,
              dataSize <= Int(UInt32.max) - 36 else {
            throw WAVError.invalidFile("Audio payload exceeds the RIFF/WAV size limit")
        }
        return (UInt32(buffer.sampleRate), dataSize)
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 { UInt16(data[offset]) | UInt16(data[offset + 1]) << 8 }
    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 { UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24 }
    private static func appendUInt16(_ value: UInt16, to data: inout Data) { data.append(UInt8(value & 0xff)); data.append(UInt8(value >> 8)) }
    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff)); data.append(UInt8((value >> 16) & 0xff)); data.append(UInt8(value >> 24))
    }
}
