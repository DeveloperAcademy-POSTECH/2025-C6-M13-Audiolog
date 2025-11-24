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
        // ✅ 모든 세션 작업을 sessionQueue에서 처리
        sessionQueue.async { [self] in
            if let spatialAudioDataOutput, let stereoAudioDataOutput {
                spatialAudioDataOutput.spatialAudioChannelLayoutTag =
                    (kAudioChannelLayoutTag_HOA_ACN_SN3D | 4)
                stereoAudioDataOutput.spatialAudioChannelLayoutTag =
                    kAudioChannelLayoutTag_Stereo
            }

            // 이미 오디오 output이 붙어 있으면 다시 구성하지 않음
            if session.outputs.contains(where: { $0 is AVCaptureAudioDataOutput }) {
                return
            }

            session.beginConfiguration()
            defer {
                session.commitConfiguration()
            }

            // 입력 추가
            if let audioDevice {
                guard let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice)
                else { return }

                if session.canAddInput(audioDeviceInput) {
                    session.addInput(audioDeviceInput)

                    if audioDeviceInput.isMultichannelAudioModeSupported(.firstOrderAmbisonics) {
                        audioDeviceInput.multichannelAudioMode = .firstOrderAmbisonics
                    }
                }
            }

            // 출력 추가
            if let stereoAudioDataOutput, let spatialAudioDataOutput {
                if session.canAddOutput(spatialAudioDataOutput) {
                    session.addOutput(spatialAudioDataOutput)
                }

                if session.canAddOutput(stereoAudioDataOutput) {
                    session.addOutput(stereoAudioDataOutput)
                }

                // ✅ delegate도 같은 큐에서 설정
                spatialAudioDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                stereoAudioDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            }
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
        await withCheckedContinuation {
            (cont: CheckedContinuation<Void, Never>) in
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
                        print(
                            "finishWriting failed:",
                            writer.error ?? "unknown error"
                        )
                    }

                    self.assetWriter = nil
                    self.assetWriterSpatialAudioInput = nil
                    self.assetWriterStereoAudioInput = nil
                    self.assetWriterMetadataInput = nil

                    if session.isRunning {
                        session.stopRunning()
                    }

                    cont.resume()
                }
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
        guard isRecordForCallBacks else { return }

        var sampleBufferToWrite: CMSampleBuffer?

        if let generator = self.spatialAudioMetaDataSampleGenerator {
            generator.analyzeAudioSample(sampleBuffer)
            sampleBufferToWrite = createAudioSampleBufferCopy(sampleBuffer)
        } else {
            sampleBufferToWrite = createSpatialAudioSampleBufferCopy(sampleBuffer)
        }

        guard isRecordForCallBacks,
              let buffer = sampleBufferToWrite else { return }

        self.assetWriterSpatialAudioInput?.append(buffer)
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
}
