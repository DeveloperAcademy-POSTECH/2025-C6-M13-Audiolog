//
//  AudioRecorder.swift
//  Audiolog
//
//  Created by Sean Cho on 10/27/25.
//

import AVFoundation
import Combine
import CoreFoundation
import CoreMedia
import Foundation

@Observable
class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate,
    @unchecked Sendable
{
    var isRecording = false
    var timeElapsed: TimeInterval = 0
    var firstBufferPTS: CMTime?
    var fileName: String = ""

    private var audioDevice: AVCaptureDevice?

    private var assetWriter: AVAssetWriter?
    private var session: AVCaptureSession
    private var stereoAudioDataOutput: AVCaptureAudioDataOutput?
    private var spatialAudioDataOutput: AVCaptureAudioDataOutput?
    private var spatialAudioMetaDataSampleGenerator:
        AVCaptureSpatialAudioMetadataSampleGenerator?
    private var assetWriterMetadataInput: AVAssetWriterInput?
    private var assetWriterSpatialAudioInput: AVAssetWriterInput?
    private var assetWriterStereoAudioInput: AVAssetWriterInput?
    private var sessionQueue: DispatchQueue
    private var isRecordForCallBacks = false

    override init() {
        session = AVCaptureSession()

        if let audioCaptureDevice = AVCaptureDevice.default(for: .audio) {
            audioDevice = audioCaptureDevice
        }

        spatialAudioDataOutput = AVCaptureAudioDataOutput()
        stereoAudioDataOutput = AVCaptureAudioDataOutput()

        spatialAudioMetaDataSampleGenerator =
            AVCaptureSpatialAudioMetadataSampleGenerator()

        sessionQueue = DispatchQueue(label: "recordSessionQueue")
    }

    func setupCaptureSession() {
        if let spatialAudioDataOutput, let stereoAudioDataOutput {
            spatialAudioDataOutput.spatialAudioChannelLayoutTag =
                (kAudioChannelLayoutTag_HOA_ACN_SN3D | 4)
            stereoAudioDataOutput.spatialAudioChannelLayoutTag =
                kAudioChannelLayoutTag_Stereo
        }

        session.beginConfiguration()

        if let audioDevice {
            guard
                let audioDeviceInput = try? AVCaptureDeviceInput(
                    device: audioDevice
                )
            else { return }

            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)

                if audioDeviceInput.isMultichannelAudioModeSupported(
                    .firstOrderAmbisonics
                ) {
                    audioDeviceInput.multichannelAudioMode =
                        .firstOrderAmbisonics
                }
            }
        }

        if let stereoAudioDataOutput, let spatialAudioDataOutput {
            if session.canAddOutput(spatialAudioDataOutput) {
                session.addOutput(spatialAudioDataOutput)
            }

            if session.canAddOutput(stereoAudioDataOutput) {
                session.addOutput(stereoAudioDataOutput)
            }
        }

        session.commitConfiguration()

        if let spatialAudioDataOutput, let stereoAudioDataOutput {
            spatialAudioDataOutput.setSampleBufferDelegate(
                self,
                queue: self.sessionQueue
            )

            stereoAudioDataOutput.setSampleBufferDelegate(
                self,
                queue: self.sessionQueue
            )
        }

        sessionQueue.async {
            self.session.startRunning()
        }
    }

    func startRecording() {
        sessionQueue.async { [self] in
            if !session.isRunning {
                session.startRunning()
            }
            isRecordForCallBacks = true
            DispatchQueue.main.async {
                self.isRecording = true
                self.timeElapsed = 0
                self.firstBufferPTS = nil
            }
        }
    }

    func stopRecording() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                self.isRecordForCallBacks = false

                guard let writer = self.assetWriter else {
                    DispatchQueue.main.async {
                        self.isRecording = false
                        self.firstBufferPTS = nil
                    }
                    cont.resume()
                    return
                }

                self.appendSpatialAudioMetadataSample()

                self.assetWriterSpatialAudioInput?.markAsFinished()
                self.assetWriterStereoAudioInput?.markAsFinished()
                self.assetWriterMetadataInput?.markAsFinished()

                writer.finishWriting { [weak self] in
                    guard let self else {
                        cont.resume()
                        return
                    }

                    DispatchQueue.main.async {
                        self.isRecording = false
                        self.firstBufferPTS = nil
                    }

                    if writer.status != .completed {
                        print("finishWriting failed:", writer.error ?? "unknown error")
                    }

                    self.assetWriter = nil
                    self.assetWriterSpatialAudioInput = nil
                    self.assetWriterStereoAudioInput = nil
                    self.assetWriterMetadataInput = nil

                    if session.isRunning {
                        session.stopRunning()
                    }

                    cont.resume()                }
            }
        }
    }

    func captureOutput(
        _ captureOutput: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {}

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if !isRecordForCallBacks {
            return
        }

        if self.assetWriter == nil {
            if let spatialOutput = spatialAudioDataOutput,
                let stereoOutput = stereoAudioDataOutput
            {

                self.setupAssetWriterWithSpatialAndStereoAudioOutput(
                    spatialOutput,
                    stereoOutput
                )

                self.assetWriter?.startWriting()

                self.assetWriter?.startSession(
                    atSourceTime: sampleBuffer.presentationTimeStamp
                )
            }
        }

        if let formatDescription = CMSampleBufferGetFormatDescription(
            sampleBuffer
        ), let spatialInput = assetWriterSpatialAudioInput,
            let stereoInput = assetWriterStereoAudioInput
        {
            let currentPTS = CMSampleBufferGetPresentationTimeStamp(
                sampleBuffer
            )
            if self.firstBufferPTS == nil {
                self.firstBufferPTS = currentPTS
            }
            if let startPTS = self.firstBufferPTS, currentPTS.isValid,
                startPTS.isValid
            {
                let elapsed = CMTimeSubtract(currentPTS, startPTS)
                let seconds = CMTimeGetSeconds(elapsed)
                if seconds.isFinite && seconds >= 0 {
                    DispatchQueue.main.async { [weak self] in
                        self?.timeElapsed = seconds
                    }
                }
            }

            let mediaType = CMFormatDescriptionGetMediaType(formatDescription)

            if mediaType == kCMMediaType_Audio {
                if spatialInput.isReadyForMoreMediaData {
                    if output == self.spatialAudioDataOutput {
                        self.appendSampleBufferForSpatialAudio(sampleBuffer)
                    }
                }

                if stereoInput.isReadyForMoreMediaData {
                    if output == self.stereoAudioDataOutput {
                        stereoInput.append(sampleBuffer)
                    }
                }
            }
        }

    }

    private func generateFileName() -> String {
        let randomURL = UUID().uuidString + ".mp4"
        return randomURL
    }

    private func setupAssetWriterWithSpatialAndStereoAudioOutput(
        _ spatialAudioOutput: AVCaptureAudioDataOutput,
        _ stereoAudioOutput: AVCaptureAudioDataOutput
    ) {
        self.fileName = generateFileName()
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        self.assetWriter = try? AVAssetWriter(url: fileURL, fileType: .mp4)

        let assetWriterSpatialAudioSettings =
            spatialAudioOutput.recommendedAudioSettingsForAssetWriter(
                writingTo: .mp4
            )

        self.assetWriterSpatialAudioInput = AVAssetWriterInput(
            mediaType: AVMediaType.audio,
            outputSettings: assetWriterSpatialAudioSettings
        )
        self.assetWriterSpatialAudioInput?.expectsMediaDataInRealTime = true

        if let assetWriter, let assetWriterSpatialAudioInput,
            assetWriter.canAdd(assetWriterSpatialAudioInput)
        {
            assetWriter.add(assetWriterSpatialAudioInput)
        }

        let assetWriterStereoAudioSettings =
            stereoAudioOutput.recommendedAudioSettingsForAssetWriter(
                writingTo: .mp4
            )

        self.assetWriterStereoAudioInput = AVAssetWriterInput(
            mediaType: AVMediaType.audio,
            outputSettings: assetWriterStereoAudioSettings
        )
        self.assetWriterStereoAudioInput?.expectsMediaDataInRealTime = true

        if let assetWriter, let assetWriterStereoAudioInput,
            assetWriter.canAdd(assetWriterStereoAudioInput)
        {
            assetWriter.add(assetWriterStereoAudioInput)
        }

        let spatialAudioMetadataFormatDescription = self
            .spatialAudioMetaDataSampleGenerator!
            .timedMetadataSampleBufferFormatDescription

        self.assetWriterMetadataInput = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: spatialAudioMetadataFormatDescription
        )
        self.assetWriterMetadataInput?.expectsMediaDataInRealTime = true

        if let assetWriter, let assetWriterMetadataInput,
            assetWriter.canAdd(assetWriterMetadataInput)
        {
            assetWriter.add(assetWriterMetadataInput)

            if let assetWriterSpatialAudioInput,
                assetWriterMetadataInput.canAddTrackAssociation(
                    withTrackOf: assetWriterSpatialAudioInput,
                    type: AVAssetTrack.AssociationType.metadataReferent.rawValue
                )
            {
                assetWriterMetadataInput.addTrackAssociation(
                    withTrackOf: assetWriterSpatialAudioInput,
                    type: AVAssetTrack.AssociationType.metadataReferent.rawValue
                )
            }
        }

        if let assetWriterSpatialAudioInput, let assetWriterStereoAudioInput {
            assetWriterStereoAudioInput.canAddTrackAssociation(
                withTrackOf: assetWriterSpatialAudioInput,
                type: AVAssetTrack.AssociationType.audioFallback.rawValue
            )

            assetWriterStereoAudioInput.marksOutputTrackAsEnabled = true
            assetWriterStereoAudioInput.marksOutputTrackAsEnabled = false

            assetWriterSpatialAudioInput.languageCode = "und"
            assetWriterSpatialAudioInput.extendedLanguageTag = "und"

        }

    }

    private func appendSpatialAudioMetadataSample() {
        if let spatialAudioMetadataSample = self
            .spatialAudioMetaDataSampleGenerator?
            .newTimedMetadataSampleBufferAndResetAnalyzer(),
            let assetWriterMetadataInput
        {
            assetWriterMetadataInput.append(
                spatialAudioMetadataSample.takeRetainedValue()
            )
        }
    }

    private func appendSampleBufferForSpatialAudio(
        _ sampleBuffer: CMSampleBuffer
    ) {
        if !isRecordForCallBacks { return }
        var sampleBufferToWrite: CMSampleBuffer?
        if self.spatialAudioMetaDataSampleGenerator != nil {
            self.spatialAudioMetaDataSampleGenerator?.analyzeAudioSample(
                sampleBuffer
            )
            sampleBufferToWrite = createAudioSampleBufferCopy(sampleBuffer)
        } else {
            sampleBufferToWrite = createSpatialAudioSampleBufferCopy(
                sampleBufferToWrite!
            )
        }

        if self.isRecordForCallBacks {
            if let sampleBuffer = sampleBufferToWrite {
                self.assetWriterSpatialAudioInput?.append(sampleBuffer)
            }
        }
    }

    private func createSpatialAudioSampleBufferCopy(
        _ sampleBuffer: CMSampleBuffer
    ) -> CMSampleBuffer {
        var sampleBufferCopy: CMSampleBuffer?

        let status = CMSampleBufferCreateCopy(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleBufferOut: &sampleBufferCopy
        )

        if status == noErr {
            return sampleBufferCopy!
        } else {
            fatalError(
                "Error: CMSampleBufferCreateCopy returned error \(status)"
            )
        }
    }

    private func createAudioSampleBufferCopy(_ sampleBuffer: CMSampleBuffer)
        -> CMSampleBuffer
    {
        var sampleBufferCopy: CMSampleBuffer?
        var blockBufferCopy: CMBlockBuffer?
        var sampleTimingArray: UnsafeMutableRawPointer?
        var sampleSize: UnsafeMutablePointer<Int>?

        let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)

        if let dataBuffer {
            let dataLength = CMBlockBufferGetDataLength(dataBuffer)
            if dataLength > 0 {
                var err = CMBlockBufferCreateContiguous(
                    allocator: kCFAllocatorDefault,
                    sourceBuffer: dataBuffer,
                    blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: dataLength,
                    flags: kCMBlockBufferAlwaysCopyDataFlag,
                    blockBufferOut: &blockBufferCopy
                )

                let formatDescription = CMSampleBufferGetFormatDescription(
                    sampleBuffer
                )
                let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
                var numSampleTimeEntries: CMItemCount = 0

                err = CMSampleBufferGetSampleTimingInfoArray(
                    sampleBuffer,
                    entryCount: 0,
                    arrayToFill: nil,
                    entriesNeededOut: &(numSampleTimeEntries)
                )
                sampleTimingArray = malloc(
                    numSampleTimeEntries * MemoryLayout<CMSampleTimingInfo>.size
                )
                let safeSampleTimingArray = sampleTimingArray
                let timingArrayPointer = unsafeBitCast(
                    safeSampleTimingArray,
                    to: UnsafeMutablePointer<CMSampleTimingInfo>.self
                )

                err = CMSampleBufferGetSampleTimingInfoArray(
                    sampleBuffer,
                    entryCount: numSampleTimeEntries,
                    arrayToFill: timingArrayPointer,
                    entriesNeededOut: nil
                )

                assert(
                    err == noErr,
                    "CMSampleBufferGetSampleTimingInfoArray failed \(err)"
                )

                var sampleSizeEntries: CMItemCount = 0
                err = CMSampleBufferGetSampleSizeArray(
                    sampleBuffer,
                    entryCount: 0,
                    arrayToFill: nil,
                    entriesNeededOut: &sampleSizeEntries
                )
                sampleSize = UnsafeMutablePointer<size_t>.allocate(
                    capacity: sampleSizeEntries
                )

                err = CMSampleBufferGetSampleSizeArray(
                    sampleBuffer,
                    entryCount: sampleSizeEntries,
                    arrayToFill: sampleSize,
                    entriesNeededOut: nil
                )

                assert(
                    err == noErr,
                    "CMSampleBufferGetSampleSizeArray failed \(err)"
                )

                err = CMSampleBufferCreate(
                    allocator: kCFAllocatorDefault,
                    dataBuffer: blockBufferCopy,
                    dataReady: true,
                    makeDataReadyCallback: nil,
                    refcon: nil,
                    formatDescription: formatDescription,
                    sampleCount: numSamples,
                    sampleTimingEntryCount: numSampleTimeEntries,
                    sampleTimingArray: timingArrayPointer,
                    sampleSizeEntryCount: sampleSizeEntries,
                    sampleSizeArray: sampleSize,
                    sampleBufferOut: &sampleBufferCopy
                )

                assert(err == noErr, "CMSampleBufferCreate failed \(err)")

                if let sampleBufferCopy {
                    CMPropagateAttachments(
                        sampleBuffer,
                        destination: sampleBufferCopy
                    )
                }
            }
        }

        return sampleBufferCopy!
    }

    //    /// FOA(ACN/SN3D) 버퍼로부터 XYZ 방향(및 방위각/고도)을 대략 추정합니다.
    //    /// 채널 순서는 [W, Y, Z, X] (ACN 순서 0..3)라고 가정합니다.
    //    /// 이는 물리적으로 정확한 DOA 해법이 아닌, 로깅을 위한 **휴리스틱**입니다.
    //    private func logFOADirection(from sampleBuffer: CMSampleBuffer) {
    //        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
    //            let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(
    //                formatDesc
    //            ),
    //            let block = CMSampleBufferGetDataBuffer(sampleBuffer)
    //        else { return }
    //
    //        let asbd = asbdPtr.pointee
    //        let channels = Int(asbd.mChannelsPerFrame)
    //        //        let bytesPerFrame = Int(asbd.mBytesPerFrame)
    //        let bitsPerChannel = Int(asbd.mBitsPerChannel)
    //
    //        // 여기서는 32비트 부동소수점 인터리브된 FOA만 처리합니다.
    //        guard channels >= 4,
    //            bitsPerChannel == 32,
    //            (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
    //        else {
    //            logger.log(
    //                "FOA log: unsupported format (channels=\(channels) bpc=\(bitsPerChannel) flags=\(asbd.mFormatFlags))"
    //            )
    //            return
    //        }
    //
    //        // 원시 바이트를 가져옵니다
    //        let length = CMBlockBufferGetDataLength(block)
    //        var data = [Float](
    //            repeating: 0,
    //            count: length / MemoryLayout<Float>.size
    //        )
    //        let status = CMBlockBufferCopyDataBytes(
    //            block,
    //            atOffset: 0,
    //            dataLength: length,
    //            destination: &data
    //        )
    //        if status != noErr || data.isEmpty {
    //            logger.log("FOA log: failed to copy bytes (\(status))")
    //            return
    //        }
    //
    //        // 프레임 전반에 걸쳐 W, Y, Z, X의 단순 평균을 누적합니다.
    //        var sumW: Double = 0
    //        var sumX: Double = 0
    //        var sumY: Double = 0
    //        var sumZ: Double = 0
    //        let frameCount = data.count / channels
    //        if frameCount == 0 { return }
    //
    //        // ACN/SN3D FOA 채널 순서는 [0:W, 1:Y, 2:Z, 3:X] 입니다.
    //        for f in 0..<frameCount {
    //            let base = f * channels
    //            let W = Double(data[base + 0])
    //            let Y = Double(data[base + 1])
    //            let Z = Double(data[base + 2])
    //            let X = Double(data[base + 3])
    //            sumW += W
    //            sumX += X
    //            sumY += Y
    //            sumZ += Z
    //        }
    //
    //        let meanW = sumW / Double(frameCount)
    //        var vx = sumX / Double(frameCount)
    //        var vy = sumY / Double(frameCount)
    //        var vz = sumZ / Double(frameCount)
    //
    //        // |W|로 정규화하여 크기를 다소 안정화합니다(매우 거친 방법).
    //        let denom = max(abs(meanW), 1e-6)
    //        vx /= denom
    //        vy /= denom
    //        vz /= denom
    //
    //        // 벡터를 단위 길이로 정규화합니다.
    //        let mag = max(sqrt(vx * vx + vy * vy + vz * vz), 1e-9)
    //        let nx = vx / mag
    //        let ny = vy / mag
    //        let nz = vz / mag
    //
    //        // 방위각(도, X=오른쪽, Y=전방)과 고도(도, Z=위쪽)를 계산합니다.
    //                let azimuth = atan2(ny, nx) * 180.0 / .pi
    //                let elevation = atan2(nz, sqrt(nx * nx + ny * ny)) * 180.0 / .pi
    //
    //                let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    //                logger.log(
    //                    String(
    //                        format:
    //                            "FOA DOA ~ ts:%@ xyz[%.3f, %.3f, %.3f] az/el[%.1f°, %.1f°] ch:%d bpf:%d",
    //                        String(describing: ts),
    //                        nx,
    //                        ny,
    //                        nz,
    //                        azimuth,
    //                        elevation,
    //                        channels,
    //                        bytesPerFrame
    //                    )
    //                )
    //    }
}
