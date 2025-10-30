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
    // 현재 녹음 중인지 나타내는 불리언 값
    var isRecording = false

    // Recording elapsed time (seconds)
    var timeElapsed: TimeInterval = 0

    // First buffer presentation timestamp (monotonic media clock)
    private var firstBufferPTS: CMTime?

    // 녹음된 오디오 파일의 URL
    var fileURL: URL?

    // 진폭 값 배열
    var amplitudes: [Float] = []

    // 앱의 AVAssetWriter
    private var assetWriter: AVAssetWriter?

    // 앱의 캡처 세션
    private var session: AVCaptureSession

    // 이 세션의 스테레오 오디오 데이터 출력
    private var stereoAudioDataOutput: AVCaptureAudioDataOutput?

    // 이 세션의 공간 오디오 데이터 출력
    private var spatialAudioDataOutput: AVCaptureAudioDataOutput?

    // 공간 오디오 메타데이터 샘플 생성기
    private var spatialAudioMetaDataSampleGenerator:
        AVCaptureSpatialAudioMetadataSampleGenerator?

    // 세션에서 사용할 오디오 디바이스
    private var audioDevice: AVCaptureDevice?

    // 메타데이터용 AVAssetWriterInput
    private var assetWriterMetadataInput: AVAssetWriterInput?

    // 공간 오디오용 AVAssetWriterInput
    private var assetWriterSpatialAudioInput: AVAssetWriterInput?

    // 스테레오 오디오용 AVAssetWriterInput
    private var assetWriterStereoAudioInput: AVAssetWriterInput?

    // 세션 및 관련 객체와 통신하는 큐
    private var sessionQueue: DispatchQueue

    // 델리게이트 콜백 처리용 녹음 상태 플래그
    private var isRecordForCallBacks = false

    override init() {
        #if targetEnvironment(simulator)
            // Simulator: Avoid configuring capture/session to prevent runtime issues.
            session = AVCaptureSession()
            audioDevice = nil
            spatialAudioDataOutput = nil
            stereoAudioDataOutput = nil
            spatialAudioMetaDataSampleGenerator = nil
            sessionQueue = DispatchQueue(label: "sessionQueue")
            self.amplitudes = []
            logger.log("AudioRecorder disabled on Simulator.")
        #else
            // 앱의 캡처 세션 초기화
            session = AVCaptureSession()

            // 캡처 세션에서 사용할 AVCaptureDevice 초기화
            if let audioCaptureDevice = AVCaptureDevice.default(for: .audio) {
                audioDevice = audioCaptureDevice
            }

            // 공간 오디오 데이터 출력 초기화
            spatialAudioDataOutput = AVCaptureAudioDataOutput()

            // 스테레오 오디오 데이터 출력 초기화
            stereoAudioDataOutput = AVCaptureAudioDataOutput()

            // 공간 오디오 메타데이터 샘플 생성기 초기화
            spatialAudioMetaDataSampleGenerator =
                AVCaptureSpatialAudioMetadataSampleGenerator()

            // sessionQueue 초기화
            sessionQueue = DispatchQueue(label: "recordSessionQueue")

            // 파형 값 관련 변수 초기화
            self.amplitudes = []
        #endif
    }

    func setupCaptureSession() {
        #if targetEnvironment(simulator)
            logger.log("setupCaptureSession skipped on Simulator")
            return
        #endif

        if let spatialAudioDataOutput, let stereoAudioDataOutput {
            // 공간 오디오 채널 레이아웃 태그를 High Order Ambisonics로 설정
            spatialAudioDataOutput.spatialAudioChannelLayoutTag =
                (kAudioChannelLayoutTag_HOA_ACN_SN3D | 4)
            // 스테레오 오디오 채널 레이아웃 태그를 표준 스테레오로 설정
            stereoAudioDataOutput.spatialAudioChannelLayoutTag =
                kAudioChannelLayoutTag_Stereo
        }

        // 캡처 세션 설정 시작
        session.beginConfiguration()

        do {
            if let audioDevice {

                // 캡처 세션용 오디오 디바이스 입력
                let audioDeviceInput = try AVCaptureDeviceInput(
                    device: audioDevice
                )

                // 오디오 디바이스 입력을 캡처 세션에 추가
                if session.canAddInput(audioDeviceInput) {
                    session.addInput(audioDeviceInput)

                    // 오디오 디바이스 입력의 다채널 오디오 모드를 1차 앰비소닉스로 설정
                    if audioDeviceInput.isMultichannelAudioModeSupported(
                        .firstOrderAmbisonics
                    ) {
                        audioDeviceInput.multichannelAudioMode =
                            .firstOrderAmbisonics
                    } else {
                        fatalError(
                            "Could not set the audio device input multichannel audio mode to first order ambisonics. Run this sample code on a device that supports Spatial Audio capture, such as an iPhone 16 Pro or later."
                        )
                    }
                } else {
                    logger.log(
                        "Could not add audio device input to the session."
                    )
                }
            } else {
                logger.log("Could not create the audio device.")
            }
        } catch {
            logger.log("Could not create audio device input: \(error).")
        }

        if let stereoAudioDataOutput, let spatialAudioDataOutput {

            // 공간 오디오 데이터 출력을 캡처 세션에 추가
            if session.canAddOutput(spatialAudioDataOutput) {
                session.addOutput(spatialAudioDataOutput)
            } else {
                logger.log(
                    "Could not add spatial audio data output to the session"
                )
            }

            // 스테레오 오디오 데이터 출력을 캡처 세션에 추가
            if session.canAddOutput(stereoAudioDataOutput) {
                session.addOutput(stereoAudioDataOutput)
            } else {
                logger.log(
                    "Could not add stereo audio data output to the session"
                )
            }
        }

        // 캡처 세션 설정 커밋
        session.commitConfiguration()

        if let spatialAudioDataOutput, let stereoAudioDataOutput {
            // 공간 오디오 데이터 출력의 샘플 버퍼 델리게이트 설정
            spatialAudioDataOutput.setSampleBufferDelegate(
                self,
                queue: self.sessionQueue
            )

            // 스테레오 오디오 데이터 출력의 샘플 버퍼 델리게이트 설정
            stereoAudioDataOutput.setSampleBufferDelegate(
                self,
                queue: self.sessionQueue
            )
        }

        sessionQueue.async {
            self.session.startRunning()
        }
    }

    // 녹음 시작 시 레코더 상태 변수 설정
    func startRecording() {
        #if targetEnvironment(simulator)
            logger.log("startRecording skipped on Simulator")
            return
        #endif
        sessionQueue.async { [self] in
            isRecordForCallBacks = true
            DispatchQueue.main.async {
                self.isRecording = true
                self.timeElapsed = 0
                self.firstBufferPTS = nil
            }
        }
    }

    // 녹음 종료 시 레코더 상태 변수 설정
    func stopRecording() async {
        #if targetEnvironment(simulator)
            logger.log("stopRecording skipped on Simulator")
            return
        #endif
        sessionQueue.async { [self] in
            self.isRecordForCallBacks = false
            DispatchQueue.main.async {
                self.isRecording = false
                self.timeElapsed = 0
                self.firstBufferPTS = nil
            }
        }
    }

    // 샘플 버퍼 드롭(delegate) 콜백
    func captureOutput(
        _ captureOutput: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        logger.log(
            "Dropped Sample Buffer: \(sampleBuffer) from  Connection: \(connection) and  output: \(captureOutput)"
        )
    }

    // 샘플 버퍼 출력(delegate) 콜백
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        #if targetEnvironment(simulator)
            return
        #endif

        // 녹음 중이 아니면 AVAssetWriter 쓰기를 마치고 nil로 해제
        if !isRecordForCallBacks {
            if self.assetWriter != nil {
                self.appendSpatialAudioMetadataSample()
                self.assetWriter?.finishWriting(completionHandler: {})
                self.assetWriter = nil
            }
            return
        }

        // Asset Writer 세션이 시작되지 않았다면 지금 시작
        if self.assetWriter == nil {
            if let spatialOutput = spatialAudioDataOutput,
                let stereoOutput = stereoAudioDataOutput
            {

                // 공간 및 스테레오 오디오 출력으로 Asset Writer 설정
                self.setupAssetWriterWithSpatialAndStereoAudioOutput(
                    spatialOutput,
                    stereoOutput
                )

                // Asset Writer 쓰기 시작
                self.assetWriter?.startWriting()

                // Asset Writer 세션 시작
                self.assetWriter?.startSession(
                    atSourceTime: sampleBuffer.presentationTimeStamp
                )
            }
        }

        // CMSampleBuffer의 포맷 설명에서 미디어 타입 추출
        if let formatDescription = CMSampleBufferGetFormatDescription(
            sampleBuffer
        ), let spatialInput = assetWriterSpatialAudioInput,
            let stereoInput = assetWriterStereoAudioInput
        {
            // Establish first PTS and update elapsed time based on media timestamps
            let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if self.firstBufferPTS == nil {
                self.firstBufferPTS = currentPTS
            }
            if let startPTS = self.firstBufferPTS, currentPTS.isValid, startPTS.isValid {
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
                        let pts = CMSampleBufferGetPresentationTimeStamp(
                            sampleBuffer
                        )
                        let dur = CMSampleBufferGetDuration(sampleBuffer)
                        let formatDesc = CMSampleBufferGetFormatDescription(
                            sampleBuffer
                        )
                        if let asbd =
                            CMAudioFormatDescriptionGetStreamBasicDescription(
                                formatDesc!
                            )?.pointee
                        {
                            logger.log(
                                "Spatial buffer received - ts: \(pts) dur: \(dur) sampleRate: \(asbd.mSampleRate) channels: \(asbd.mChannelsPerFrame)"
                            )
                        } else {
                            logger.log(
                                "Spatial buffer received - ts: \(pts) dur: \(dur) (no ASBD)"
                            )
                        }
                        self.logFOADirection(from: sampleBuffer)
                        // 공간 오디오 입력에 샘플 버퍼 추가
                        self.appendSampleBufferForSpatialAudio(sampleBuffer)
                    }
                }

                if stereoInput.isReadyForMoreMediaData {
                    if output == self.stereoAudioDataOutput {
                        logger.log(
                            "Stereo buffer received at: \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) duration: \(CMSampleBufferGetDuration(sampleBuffer))"
                        )
                        // 스테레오 오디오 입력에 샘플 버퍼 추가
                        stereoInput.append(sampleBuffer)
                        // 샘플 버퍼로부터 녹음 파형 UI에 사용할 값 계산
                        computeValuesForWaveFormUI(sampleBuffer)
                    }
                }
            }
        }

    }

    // 녹음 파일 URL을 생성하는 유틸리티 함수
    private func generateURL() -> URL {
        let fileManager = FileManager.default
        guard
            let documentsURL = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            fatalError(
                "The app failed to recieve a url to the document directory"
            )
        }
        let randomFileName = UUID().uuidString + ".mp4"
        let randomURL = documentsURL.appendingPathComponent(randomFileName)
        return randomURL
    }

    // 공간/스테레오 오디오 출력을 모두 사용하는 Asset Writer 설정 함수
    private func setupAssetWriterWithSpatialAndStereoAudioOutput(
        _ spatialAudioOutput: AVCaptureAudioDataOutput,
        _ stereoAudioOutput: AVCaptureAudioDataOutput
    ) {

        // 녹음 파일 URL 생성 및 할당
        let writableFileURL = generateURL()
        self.fileURL = writableFileURL

        guard let fileURL else {
            fatalError("Unable to obtain file URL.")
        }

        do {
            // AVAssetWriter 생성
            self.assetWriter = try AVAssetWriter(url: fileURL, fileType: .mp4)

        } catch {
            logger.log("Could not create AVAssetWriter: \(error).")
        }

        // 공간 오디오 출력 설정 구성
        let assetWriterSpatialAudioSettings =
            spatialAudioOutput.recommendedAudioSettingsForAssetWriter(
                writingTo: .mp4
            )

        // 공간 오디오용 writer input 생성
        self.assetWriterSpatialAudioInput = AVAssetWriterInput(
            mediaType: AVMediaType.audio,
            outputSettings: assetWriterSpatialAudioSettings
        )
        self.assetWriterSpatialAudioInput?.expectsMediaDataInRealTime = true

        // 공간 오디오 입력을 asset writer에 추가
        if let assetWriter, let assetWriterSpatialAudioInput,
            assetWriter.canAdd(assetWriterSpatialAudioInput)
        {
            assetWriter.add(assetWriterSpatialAudioInput)
        }

        // 스테레오 오디오 출력 설정 구성
        let assetWriterStereoAudioSettings =
            stereoAudioOutput.recommendedAudioSettingsForAssetWriter(
                writingTo: .mp4
            )

        // 스테레오 오디오용 writer input 생성
        self.assetWriterStereoAudioInput = AVAssetWriterInput(
            mediaType: AVMediaType.audio,
            outputSettings: assetWriterStereoAudioSettings
        )
        self.assetWriterStereoAudioInput?.expectsMediaDataInRealTime = true

        // 스테레오 오디오 입력을 asset writer에 추가
        if let assetWriter, let assetWriterStereoAudioInput,
            assetWriter.canAdd(assetWriterStereoAudioInput)
        {
            assetWriter.add(assetWriterStereoAudioInput)
        }

        // 공간 오디오 메타데이터 샘플 생성기 출력의 포맷 설명 지정
        let spatialAudioMetadataFormatDescription = self
            .spatialAudioMetaDataSampleGenerator!
            .timedMetadataSampleBufferFormatDescription

        // 메타데이터용 writer input 생성
        self.assetWriterMetadataInput = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: spatialAudioMetadataFormatDescription
        )
        self.assetWriterMetadataInput?.expectsMediaDataInRealTime = true

        // 공간 메타데이터 입력을 asset writer에 추가
        if let assetWriter, let assetWriterMetadataInput,
            assetWriter.canAdd(assetWriterMetadataInput)
        {
            assetWriter.add(assetWriterMetadataInput)

            // 메타데이터 입력에 공간 오디오 입력의 트랙 연관을 추가합니다.
            if let assetWriterSpatialAudioInput,
                assetWriterMetadataInput.canAddTrackAssociation(
                    withTrackOf: assetWriterSpatialAudioInput,
                    type: AVAssetTrack.AssociationType.metadataReferent.rawValue
                )
            {
                // 메타데이터 입력에 공간 오디오 입력의 트랙 연관을 추가합니다.
                assetWriterMetadataInput.addTrackAssociation(
                    withTrackOf: assetWriterSpatialAudioInput,
                    type: AVAssetTrack.AssociationType.metadataReferent.rawValue
                )
            }
        }

        // 스테레오/공간 트랙의 폴백 관계 추가 및 활성/비활성 표시
        if let assetWriterSpatialAudioInput, let assetWriterStereoAudioInput {
            assetWriterStereoAudioInput.canAddTrackAssociation(
                withTrackOf: assetWriterSpatialAudioInput,
                type: AVAssetTrack.AssociationType.audioFallback.rawValue
            )

            // 스테레오 오디오 입력의 출력 트랙을 활성화 후 비활성화로 표시
            assetWriterStereoAudioInput.marksOutputTrackAsEnabled = true
            assetWriterStereoAudioInput.marksOutputTrackAsEnabled = false

            // 모든 오디오 트랙에 동일한 alternate group ID를 부여하고 언어/확장 태그를 "und"로 설정
            assetWriterSpatialAudioInput.languageCode = "und"
            assetWriterSpatialAudioInput.extendedLanguageTag = "und"

        }

    }

    // 파형 UI 시각화를 위한 오디오 샘플의 진폭 값 계산 함수
    private func computeValuesForWaveFormUI(_ sampleBuffer: CMSampleBuffer) {

        // 오디오 데이터를 포함한 블록 버퍼 가져오기
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        // 버퍼 크기 확인 및 Float 샘플 배열 준비
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var floatData = [Float](
            repeating: 0,
            count: length / MemoryLayout<Float>.size
        )

        // 원시 오디오 데이터를 float 배열로 복사
        let status = CMBlockBufferCopyDataBytes(
            blockBuffer,
            atOffset: 0,
            dataLength: length,
            destination: &floatData
        )
        guard status == noErr else { return }

        // 오디오 신호의 RMS(제곱평균제곱근) 값 계산
        // RMS는 오디오 진폭을 나타내는 지표
        let rms = sqrt(
            floatData.map { $0 * $0 }.reduce(0, +) / Float(floatData.count)
        )

        // RMS 값을 최대 1.0으로 클램핑하여 정규화
        let normalized = min(rms, 1.0)

        // 메인 스레드에서 amplitudes 배열에 값을 추가하여 UI 업데이트
        DispatchQueue.main.async {
            self.amplitudes.append(normalized)
            // 표시를 위해 배열 크기를 최대 100개 샘플로 유지
            if self.amplitudes.count > 100 {
                self.amplitudes.removeFirst()
            }
        }
    }

    // 공간 오디오 메타데이터 샘플을 asset writer 입력에 추가하는 함수
    private func appendSpatialAudioMetadataSample() {
        if let spatialAudioMetadataSample = self
            .spatialAudioMetaDataSampleGenerator?
            .newTimedMetadataSampleBufferAndResetAnalyzer(),
            let assetWriterMetadataInput
        {
            assetWriterMetadataInput.append(
                spatialAudioMetadataSample.takeRetainedValue()
            )
        } else {
            fatalError("Was not able to get final sample buffer.")
        }
    }

    // 분석된 공간 오디오 샘플 버퍼를 asset writer 입력에 추가하는 함수
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

    // 주어진 CMSampleBuffer를 복사하는 함수 (실패 시 fatalError)
    private func createSpatialAudioSampleBufferCopy(
        _ sampleBuffer: CMSampleBuffer
    )
        -> CMSampleBuffer
    {
        var sampleBufferCopy: CMSampleBuffer?

        let status = CMSampleBufferCreateCopy(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleBufferOut: &sampleBufferCopy
        )

        if status == noErr {
            return sampleBufferCopy!  // CMSampleBuffer를 반환합니다
        } else {
            fatalError(
                "Error: CMSampleBufferCreateCopy returned error \(status)"
            )
        }
    }

    // 오디오 데이터를 포함한 CMSampleBuffer의 딥 카피를 생성하는 함수
    private func createAudioSampleBufferCopy(_ sampleBuffer: CMSampleBuffer)
        -> CMSampleBuffer
    {

        // 새 버퍼 및 메타데이터를 위한 변수 선언
        var sampleBufferCopy: CMSampleBuffer?
        var blockBufferCopy: CMBlockBuffer?
        var sampleTimingArray: UnsafeMutableRawPointer?
        var sampleSize: UnsafeMutablePointer<Int>?

        // 원본 샘플 버퍼에서 데이터 버퍼 가져오기
        let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)

        if let dataBuffer {
            let dataLength = CMBlockBufferGetDataLength(dataBuffer)
            if dataLength > 0 {

                // 데이터 버퍼가 존재하고 데이터가 있으면 길이를 구하고 연속된 딥 카피(CMBlockBuffer) 생성
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

                // 오디오 포맷 설명과 샘플 수 추출
                let formatDescription = CMSampleBufferGetFormatDescription(
                    sampleBuffer
                )
                let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
                var numSampleTimeEntries: CMItemCount = 0

                // 샘플 타이밍 정보 복사
                // 먼저 필요한 개수 확인
                // 타이밍 배열 메모리 할당
                // 원본 버퍼의 타이밍 데이터로 배열 채우기
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

                // 각 샘플의 바이트 크기를 sampleSize에 채움
                err = CMSampleBufferGetSampleTimingInfoArray(
                    sampleBuffer,
                    entryCount: numSampleTimeEntries,
                    arrayToFill: timingArrayPointer,
                    entriesNeededOut: nil
                )

                // 함수 성공 여부 확인용 어설션
                assert(
                    err == noErr,
                    "CMSampleBufferGetSampleTimingInfoArray failed \(err)"
                )

                // 샘플 크기 정보 복사 — 위와 동일: 개수 확인, 메모리 할당, 값 채우기
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

                // 각 샘플의 크기를 sampleSize에 채움
                err = CMSampleBufferGetSampleSizeArray(
                    sampleBuffer,
                    entryCount: sampleSizeEntries,
                    arrayToFill: sampleSize,
                    entriesNeededOut: nil
                )

                // 함수 성공 여부 확인용 어설션
                assert(
                    err == noErr,
                    "CMSampleBufferGetSampleSizeArray failed \(err)"
                )

                // 복사된 데이터를 사용해 새 샘플 버퍼 생성
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

                // 함수 성공 여부 확인용 어설션
                assert(err == noErr, "CMSampleBufferCreate failed \(err)")

                if let sampleBufferCopy {
                    // 원본 버퍼의 메타데이터 첨부 정보를 새 버퍼로 복사
                    CMPropagateAttachments(
                        sampleBuffer,
                        destination: sampleBufferCopy
                    )
                }

            }
        }

        // 복사된 샘플 버퍼 반환
        return sampleBufferCopy!
    }

    /// FOA(ACN/SN3D) 버퍼로부터 XYZ 방향(및 방위각/고도)을 대략 추정합니다.
    /// 채널 순서는 [W, Y, Z, X] (ACN 순서 0..3)라고 가정합니다.
    /// 이는 물리적으로 정확한 DOA 해법이 아닌, 로깅을 위한 **휴리스틱**입니다.
    private func logFOADirection(from sampleBuffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
            let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(
                formatDesc
            ),
            let block = CMSampleBufferGetDataBuffer(sampleBuffer)
        else { return }

        let asbd = asbdPtr.pointee
        let channels = Int(asbd.mChannelsPerFrame)
        let bytesPerFrame = Int(asbd.mBytesPerFrame)
        let bitsPerChannel = Int(asbd.mBitsPerChannel)

        // 여기서는 32비트 부동소수점 인터리브된 FOA만 처리합니다.
        guard channels >= 4,
            bitsPerChannel == 32,
            (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        else {
            logger.log(
                "FOA log: unsupported format (channels=\(channels) bpc=\(bitsPerChannel) flags=\(asbd.mFormatFlags))"
            )
            return
        }

        // 원시 바이트를 가져옵니다
        let length = CMBlockBufferGetDataLength(block)
        var data = [Float](
            repeating: 0,
            count: length / MemoryLayout<Float>.size
        )
        let status = CMBlockBufferCopyDataBytes(
            block,
            atOffset: 0,
            dataLength: length,
            destination: &data
        )
        if status != noErr || data.isEmpty {
            logger.log("FOA log: failed to copy bytes (\(status))")
            return
        }

        // 프레임 전반에 걸쳐 W, Y, Z, X의 단순 평균을 누적합니다.
        var sumW: Double = 0
        var sumX: Double = 0
        var sumY: Double = 0
        var sumZ: Double = 0
        let frameCount = data.count / channels
        if frameCount == 0 { return }

        // ACN/SN3D FOA 채널 순서는 [0:W, 1:Y, 2:Z, 3:X] 입니다.
        for f in 0..<frameCount {
            let base = f * channels
            let W = Double(data[base + 0])
            let Y = Double(data[base + 1])
            let Z = Double(data[base + 2])
            let X = Double(data[base + 3])
            sumW += W
            sumX += X
            sumY += Y
            sumZ += Z
        }

        let meanW = sumW / Double(frameCount)
        var vx = sumX / Double(frameCount)
        var vy = sumY / Double(frameCount)
        var vz = sumZ / Double(frameCount)

        // |W|로 정규화하여 크기를 다소 안정화합니다(매우 거친 방법).
        let denom = max(abs(meanW), 1e-6)
        vx /= denom
        vy /= denom
        vz /= denom

        // 벡터를 단위 길이로 정규화합니다.
        let mag = max(sqrt(vx * vx + vy * vy + vz * vz), 1e-9)
        let nx = vx / mag
        let ny = vy / mag
        let nz = vz / mag

        // 방위각(도, X=오른쪽, Y=전방)과 고도(도, Z=위쪽)를 계산합니다.
        let azimuth = atan2(ny, nx) * 180.0 / .pi
        let elevation = atan2(nz, sqrt(nx * nx + ny * ny)) * 180.0 / .pi

        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        logger.log(
            String(
                format:
                    "FOA DOA ~ ts:%@ xyz[%.3f, %.3f, %.3f] az/el[%.1f°, %.1f°] ch:%d bpf:%d",
                String(describing: ts),
                nx,
                ny,
                nz,
                azimuth,
                elevation,
                channels,
                bytesPerFrame
            )
        )
    }
}
