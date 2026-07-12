import Foundation

public enum WAVError: Error, CustomStringConvertible, Sendable {
    case invalidFile(String)
    case unsupportedFormat(audioFormat: UInt16, bitsPerSample: UInt16, channels: UInt16)

    public var description: String {
        switch self {
        case let .invalidFile(reason): "Invalid WAV file: \(reason)"
        case let .unsupportedFormat(format, bits, channels): "Unsupported WAV format \(format), \(bits)-bit, \(channels) channels. Use mono/stereo PCM16 or Float32."
        }
    }
}

public enum WAVFile {
    public static func read(url: URL) throws -> AudioBuffer {
        let data = try Data(contentsOf: url)
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
                format = (readUInt16(data, start), readUInt16(data, start + 2), readUInt32(data, start + 4), readUInt16(data, start + 14))
            } else if id == "data" { audioData = data.subdata(in: start..<end) }
            offset = end + (size % 2)
        }
        guard let format, let audioData else { throw WAVError.invalidFile("Missing fmt or data chunk") }
        guard (format.channels == 1 || format.channels == 2), (format.audio == 1 && format.bits == 16) || (format.audio == 3 && format.bits == 32) else {
            throw WAVError.unsupportedFormat(audioFormat: format.audio, bitsPerSample: format.bits, channels: format.channels)
        }
        let bytesPerSample = Int(format.bits / 8), channelCount = Int(format.channels)
        let frameCount = audioData.count / (bytesPerSample * channelCount)
        var channels = Array(repeating: Array(repeating: Float.zero, count: frameCount), count: channelCount)
        audioData.withUnsafeBytes { raw in
            for frame in 0..<frameCount { for channel in 0..<channelCount {
                let byteOffset = (frame * channelCount + channel) * bytesPerSample
                if format.audio == 1 {
                    let value = Int16(bitPattern: UInt16(raw[byteOffset]) | UInt16(raw[byteOffset + 1]) << 8)
                    channels[channel][frame] = Float(value) / 32_768
                } else {
                    let bits = UInt32(raw[byteOffset]) | UInt32(raw[byteOffset + 1]) << 8 | UInt32(raw[byteOffset + 2]) << 16 | UInt32(raw[byteOffset + 3]) << 24
                    channels[channel][frame] = Float(bitPattern: bits)
                }
            }}
        }
        return AudioBuffer(channels: channels, sampleRate: Double(format.sampleRate))
    }

    public static func writeFloat32(_ buffer: AudioBuffer, url: URL) throws {
        let dataSize = buffer.frameCount * buffer.channelCount * 4
        var output = Data()
        output.append(contentsOf: Array("RIFF".utf8)); appendUInt32(UInt32(36 + dataSize), to: &output)
        output.append(contentsOf: Array("WAVEfmt ".utf8)); appendUInt32(16, to: &output)
        appendUInt16(3, to: &output); appendUInt16(UInt16(buffer.channelCount), to: &output)
        appendUInt32(UInt32(buffer.sampleRate), to: &output)
        appendUInt32(UInt32(buffer.sampleRate) * UInt32(buffer.channelCount) * 4, to: &output)
        appendUInt16(UInt16(buffer.channelCount * 4), to: &output); appendUInt16(32, to: &output)
        output.append(contentsOf: Array("data".utf8)); appendUInt32(UInt32(dataSize), to: &output)
        for frame in 0..<buffer.frameCount { for channel in 0..<buffer.channelCount { appendUInt32(buffer.channels[channel][frame].bitPattern, to: &output) } }
        try output.write(to: url, options: .atomic)
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 { UInt16(data[offset]) | UInt16(data[offset + 1]) << 8 }
    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 { UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24 }
    private static func appendUInt16(_ value: UInt16, to data: inout Data) { data.append(UInt8(value & 0xff)); data.append(UInt8(value >> 8)) }
    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff)); data.append(UInt8((value >> 16) & 0xff)); data.append(UInt8(value >> 24))
    }
}
