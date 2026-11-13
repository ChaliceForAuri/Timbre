#if os(macOS)
    import CoreAudio
    import Foundation

    /// The Mac's audio input devices, through Core Audio: which one is the
    /// default, how it is connected, and which one is built in. Used by the
    /// fallback that rescues a dictation from a headset that is connected but
    /// not delivering (ADR-0012).
    nonisolated public enum InputDevices {

        /// The system default input, or nil when there is none.
        public static func defaultInput() -> AudioDeviceID? {
            var id = AudioDeviceID(kAudioObjectUnknown)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
            return status == noErr && id != kAudioObjectUnknown ? id : nil
        }

        /// True for Bluetooth and Bluetooth LE devices — the ones that can be
        /// connected and silent at the same time, because another device holds
        /// their microphone link.
        public static func isBluetooth(_ device: AudioDeviceID) -> Bool {
            let transport = transportType(of: device)
            return transport == kAudioDeviceTransportTypeBluetooth
                || transport == kAudioDeviceTransportTypeBluetoothLE
        }

        /// The built-in microphone, or nil on a Mac without one (a Mac Studio
        /// with no mic attached, say).
        public static func builtInInput() -> AudioDeviceID? {
            allDevices().first { device in
                transportType(of: device) == kAudioDeviceTransportTypeBuiltIn && inputChannels(of: device) > 0
            }
        }

        public static func name(of device: AudioDeviceID) -> String {
            var name: CFString = "" as CFString
            var size = UInt32(MemoryLayout<CFString>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = withUnsafeMutablePointer(to: &name) { pointer in
                AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
            }
            return status == noErr ? name as String : "device \(device)"
        }

        // MARK: - Plumbing

        private static func transportType(of device: AudioDeviceID) -> UInt32 {
            var transport: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport) == noErr else {
                return 0
            }
            return transport
        }

        private static func inputChannels(of device: AudioDeviceID) -> Int {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else {
                return 0
            }
            let buffer = UnsafeMutableRawPointer.allocate(
                byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { buffer.deallocate() }
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, buffer) == noErr else {
                return 0
            }
            let list = UnsafeMutableAudioBufferListPointer(
                buffer.assumingMemoryBound(to: AudioBufferList.self))
            return list.reduce(0) { $0 + Int($1.mNumberChannels) }
        }

        private static func allDevices() -> [AudioDeviceID] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var size: UInt32 = 0
            guard
                AudioObjectGetPropertyDataSize(
                    AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr
            else { return [] }
            var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
            guard
                AudioObjectGetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr
            else { return [] }
            return devices
        }
    }
#endif
