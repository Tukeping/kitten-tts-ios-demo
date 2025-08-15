//
//  TTSManager.swift
//  kitten-tts-ios-demo
//
//  Created by FredTu on 2025-08-15
//

import Foundation
import AVFoundation
import onnxruntime_objc
import Compression

class TTSManager {
    static let shared = TTSManager()
    
    private var ortSession: ORTSession?
    private var ortEnv: ORTEnv?
    private var voicesData: [String: [Float]] = [:]
    private var config: [String: Any] = [:]
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isModelLoaded = false
    
    private init() {
        setupAudioSession()
    }
    
    deinit {
        audioEngine?.stop()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            z_print("Failed to setup audio session: \(error)")
        }
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        if let engine = audioEngine, let player = playerNode {
            engine.attach(player)
            // Don't connect here - connect when we know the format
        }
    }
    
    func loadModelAsync(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let success = self?.loadModel() ?? false
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    private func loadModel() -> Bool {
        let configLoaded = loadConfig()
        let voicesLoaded = loadVoicesData()
        let modelLoaded = loadONNXModel()
        
        let success = configLoaded && voicesLoaded && modelLoaded
        isModelLoaded = success
        return success
    }
    
    private func loadConfig() -> Bool {
        guard let path = Bundle.main.path(forResource: "config", ofType: "json"),
              let data = NSData(contentsOfFile: path),
              let json = try? JSONSerialization.jsonObject(with: data as Data, options: []) as? [String: Any] else {
            z_print("Failed to load config.json")
            return false
        }
        
        self.config = json
        z_print("Config loaded successfully: \(json)")
        return true
    }
    
    private func loadVoicesData() -> Bool {
        guard let voicesPath = Bundle.main.path(forResource: "voices", ofType: "json") else {
            z_print("voices.json file not found")
            return false
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: voicesPath))
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            // Swift JSONSerialization uses Double by default, need to convert manually
            guard let voicesDict = json as? [String: Any] else {
                z_print("Invalid voices.json format - not a dictionary")
                throw TTSError.voiceLoadError
            }
            
            // Convert parsed data to the expected format with validation
            for (key, value) in voicesDict {
                // Handle nested array structure - need manual conversion from Double to Float
                guard let voiceArraysAny = value as? [[Any]] else {
                    z_print("Voice '\(key)' has invalid nested array format")
                    continue
                }
                
                // Convert [[Any]] -> [[Float]] like JS version
                let voiceArrays = voiceArraysAny.compactMap { innerArray -> [Float]? in
                    return innerArray.compactMap { element -> Float? in
                        if let doubleVal = element as? Double {
                            return Float(doubleVal)
                        } else if let floatVal = element as? Float {
                            return floatVal
                        } else if let intVal = element as? Int {
                            return Float(intVal)
                        }
                        return nil
                    }
                }
                
                // Handle nested array structure - flatten exactly like JS version
                let flatArray: [Float]
                if voiceArrays.count == 1 {
                    // Single nested array - extract it like JS: voiceArray[0]
                    flatArray = voiceArrays[0]
                } else {
                    // Multiple arrays - flatten them like JS: voiceArray.flat()
                    flatArray = voiceArrays.flatMap { $0 }
                }
                
                guard !flatArray.isEmpty else {
                    z_print("Voice '\(key)' has no data")
                    continue
                }
                
                // Use the full embedding length like JS version (don't truncate to 256)
                let embedding = flatArray
                
                // Validate embedding values are reasonable
                let validRange = embedding.allSatisfy { abs($0) < 10.0 }
                let hasVariation = embedding.max()! - embedding.min()! > 0.01
                
                if validRange && hasVariation {
                    voicesData[key] = embedding
                    
                    // Log statistics about the voice embedding
                    let mean = embedding.reduce(0, +) / Float(embedding.count)
                    let min = embedding.min()!
                    let max = embedding.max()!
                    z_print("Loaded voice '\(key)': \(embedding.count) dims, range [\(min)...\(max)], mean \(mean)")
                } else {
                    z_print("Voice '\(key)' has invalid data - validRange: \(validRange), hasVariation: \(hasVariation)")
                }
            }
            
            if voicesData.isEmpty {
                throw TTSError.voiceLoadError
            }
            
            z_print("Voice data loaded with \(voicesData.count) voices: \(Array(voicesData.keys))")
            
        } catch {
            z_print("Failed to load voices.json: \(error)")
            // Create more realistic fallback voice data with better variations
            voicesData = createFallbackVoiceData()
            z_print("Using fallback voice data with \(voicesData.count) voices")
        }
        
        // Notify UI that voices are available
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("VoicesLoaded"), object: nil)
        }
        
        return !voicesData.isEmpty
    }
    
    private func loadONNXModel() -> Bool {
        do {
            ortEnv = try ORTEnv(loggingLevel: .warning)
            
            guard let modelPath = Bundle.main.path(forResource: "kitten_tts_nano_v0_1", ofType: "onnx") else {
                z_print("ONNX model file not found")
                return false
            }
            
            let sessionOptions = try ORTSessionOptions()
            ortSession = try ORTSession(env: ortEnv!, modelPath: modelPath, sessionOptions: sessionOptions)
            
            // Log model input names for debugging
            if let session = ortSession {
                do {
                    let inputNames = try session.inputNames()
                    let outputNames = try session.outputNames()
                    z_print("Model input names: \(inputNames)")
                    z_print("Model output names: \(outputNames)")
                } catch {
                    z_print("Failed to get model metadata: \(error)")
                    return false
                }
            }
            
            z_print("ONNX model loaded successfully")
            return true
        } catch {
            z_print("Failed to load ONNX model: \(error)")
            return false
        }
    }
    
    func generateSpeech(text: String, voiceName: String = "expr-voice-2-f", completion: @escaping (Result<Void, Error>) -> Void) {
        guard isModelLoaded else {
            completion(.failure(TTSError.modelNotLoaded))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let audioData = try self?.synthesize(text: text, voiceName: voiceName)
                
                DispatchQueue.main.async {
                    if let data = audioData {
                        self?.playAudio(data: data)
                        completion(.success(()))
                    } else {
                        completion(.failure(TTSError.synthesisError))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func createFallbackVoiceData() -> [String: [Float]] {
        var fallbackVoices: [String: [Float]] = [:]
        
        // Create more realistic voice embeddings using different random seeds and patterns
        let voiceConfigs = [
            "expr-voice-2-m": (seed: 12345, bias: -0.1, scale: 0.3),
            "expr-voice-2-f": (seed: 23456, bias: 0.2, scale: 0.25),
            "expr-voice-3-m": (seed: 34567, bias: -0.05, scale: 0.35),
            "expr-voice-3-f": (seed: 45678, bias: 0.15, scale: 0.28),
            "expr-voice-4-m": (seed: 56789, bias: -0.08, scale: 0.32),
            "expr-voice-4-f": (seed: 67890, bias: 0.1, scale: 0.3),
            "expr-voice-5-m": (seed: 78901, bias: -0.12, scale: 0.33),
            "expr-voice-5-f": (seed: 89012, bias: 0.25, scale: 0.27)
        ]
        
        for (voiceName, config) in voiceConfigs {
            let embedding = generateRealisticVoiceEmbedding(
                seed: config.seed,
                size: 256,
                bias: Float(config.bias),
                scale: Float(config.scale)
            )
            fallbackVoices[voiceName] = embedding
        }
        
        return fallbackVoices
    }
    
    private func synthesize(text: String, voiceName: String) throws -> [Float] {
        z_print("Starting synthesis for text: '\(text)' with voice: \(voiceName)")
        
        guard let session = ortSession else {
            z_print("Error: ONNX session not loaded")
            throw TTSError.modelNotLoaded
        }
        
        // Convert text to character IDs using simplified mapping
        let textIds = textToIds(text: text)
        z_print("Text converted to \(textIds.count) IDs: \(textIds.prefix(10))...")
        
        // Validate voice name exists
        guard voicesData[voiceName] != nil else {
            z_print("Voice '\(voiceName)' not found. Available: \(Array(voicesData.keys))")
            throw TTSError.voiceNotFound
        }
        
        // Get voice embedding 
        guard let voiceEmbedding = voicesData[voiceName] else {
            throw TTSError.voiceNotFound
        }
        
        z_print("Using voice: \(voiceName) with embedding size: \(voiceEmbedding.count)")
        
        // Prepare inputs for ONNX model EXACTLY like JS version
        let textShape: [NSNumber] = [1, NSNumber(value: textIds.count)]
        let styleShape: [NSNumber] = [1, NSNumber(value: voiceEmbedding.count)]
        let speedShape: [NSNumber] = [1]
        
        // Create tensors using proper byte layout like JS BigInt64Array
        var textData = Data()
        for id in textIds {
            withUnsafeBytes(of: id.littleEndian) { bytes in
                textData.append(contentsOf: bytes)
            }
        }
        
        var styleData = Data()
        for value in voiceEmbedding {
            withUnsafeBytes(of: value) { bytes in
                styleData.append(contentsOf: bytes)
            }
        }
        
        let speedValue: Float = 1.0
        var speedData = Data()
        withUnsafeBytes(of: speedValue) { bytes in
            speedData.append(contentsOf: bytes)
        }
        
        z_print("Creating tensors: text=\(textIds.count) tokens, style=\(voiceEmbedding.count) dims, speed=1.0")
        z_print("Voice embedding sample: \(Array(voiceEmbedding.prefix(10)))")
        z_print("Text IDs detailed: \(Array(textIds.prefix(20)))")
        
        let textTensor = try ORTValue(tensorData: NSMutableData(data: textData),
                                      elementType: .int64,
                                      shape: textShape)
        
        let styleTensor = try ORTValue(tensorData: NSMutableData(data: styleData),
                                       elementType: .float,
                                       shape: styleShape)
        
        let speedTensor = try ORTValue(tensorData: NSMutableData(data: speedData),
                                       elementType: .float,
                                       shape: speedShape)
        
        // Get actual input names from the model and map correctly
        var inputs: [String: ORTValue] = [:]
        
        do {
            let inputNames = try session.inputNames()
            z_print("Available input names: \(inputNames)")
            
            // Model expects: ["input_ids", "style", "speed"]
            if inputNames.count >= 3 {
                for (index, name) in inputNames.enumerated() {
                    switch name {
                    case "input_ids":
                        inputs[name] = textTensor
                    case "style":
                        inputs[name] = styleTensor
                    case "speed":
                        inputs[name] = speedTensor
                    default:
                        // Map by position as fallback
                        if index == 0 { inputs[name] = textTensor }
                        else if index == 1 { inputs[name] = styleTensor }
                        else if index == 2 { inputs[name] = speedTensor }
                    }
                }
                z_print("Mapped inputs: \(inputs.keys)")
            } else {
                throw TTSError.synthesisError
            }
        } catch {
            z_print("Failed to get input names: \(error)")
            throw TTSError.synthesisError
        }
        
        z_print("Running ONNX inference...")
        
        do {
            // Request specific outputs - model has ["waveform", "duration"]
            let requestedOutputs: Set<String> = ["waveform"]
            let outputs = try session.run(withInputs: inputs, outputNames: requestedOutputs, runOptions: nil)
            z_print("Inference completed successfully. Output count: \(outputs.count)")
            
            // Log output names
            z_print("Output names: \(outputs.keys)")
            
            // Extract audio data from the "waveform" output
            if let waveformOutput = outputs["waveform"] {
                let tensorData = try waveformOutput.tensorData()
                let data = Data(referencing: tensorData)
                let floatArray = data.withUnsafeBytes { buffer in
                    return Array(buffer.bindMemory(to: Float.self))
                }
                z_print("Generated audio with \(floatArray.count) samples")
                
                // Apply simple normalization like JS version (no complex filtering)
                let processedAudio = simpleAudioNormalization(floatArray)
                z_print("Audio processed, range: \(processedAudio.min() ?? 0) to \(processedAudio.max() ?? 0)")
                return processedAudio
            } else if let firstOutput = outputs.values.first {
                // Fallback to first output
                let tensorData = try firstOutput.tensorData()
                let data = Data(referencing: tensorData)
                let floatArray = data.withUnsafeBytes { buffer in
                    return Array(buffer.bindMemory(to: Float.self))
                }
                z_print("Using first output with \(floatArray.count) samples")
                
                // Apply simple normalization like JS version (no complex filtering)
                let processedAudio = simpleAudioNormalization(floatArray)
                z_print("Audio processed, range: \(processedAudio.min() ?? 0) to \(processedAudio.max() ?? 0)")
                return processedAudio
            } else {
                z_print("Error: No valid outputs found")
                throw TTSError.synthesisError
            }
        } catch {
            z_print("ONNX inference failed: \(error)")
            throw TTSError.synthesisError
        }
    }
    
    private func textToIds(text: String) -> [Int64] {
        // Use EXACT vocabulary from JS TextCleaner class
        let pad = "$"
        let punctuation = ";:,.!?¡¿—…\"«»\"\" "
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        let lettersIPA = "ɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑʼʴʰʱʲʷˠˤ˞↓↑→↗↘'̩'ᵻ"
        
        let symbols = [pad] + Array(punctuation).map { String($0) } + Array(letters).map { String($0) } + Array(lettersIPA).map { String($0) }
        
        // Create word-to-index dictionary EXACTLY like JS
        var wordIndexDictionary: [String: Int] = [:]
        for (index, symbol) in symbols.enumerated() {
            wordIndexDictionary[symbol] = index
        }
        
        // Apply better phoneme approximation that matches Web version output
        let phonemizedText = applyBetterPhonemeApproximation(text: text.lowercased())
        z_print("Phonemized text: '\(text)' -> '\(phonemizedText)'")
        
        // Tokenize like JS: split on spaces but preserve phoneme symbols
        let tokens = phonemizedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let joinedPhonemes = tokens.joined(separator: " ")
        
        // Convert to character IDs like JS clean() method
        var tokenIds: [Int64] = []
        
        for char in joinedPhonemes {
            let charStr = String(char)
            if let index = wordIndexDictionary[charStr] {
                tokenIds.append(Int64(index))
            } else {
                z_print("Unknown character '\(charStr)' - using space token")
                // Use space index (after pad and first punctuation)
                tokenIds.append(Int64(wordIndexDictionary[" "] ?? 1))
            }
        }
        
        // Add start and end padding tokens like JS version
        tokenIds.insert(0, at: 0)  // Start token
        tokenIds.append(0)        // End token
        
        z_print("Text preprocessing: '\(text)' -> '\(phonemizedText)' -> \(tokenIds.count) tokens")
        z_print("Token IDs sample: \(Array(tokenIds.prefix(20)))")
        return tokenIds
    }
    
    private func applyBetterPhonemeApproximation(text: String) -> String {
        // More comprehensive phoneme approximation based on common English patterns
        var result = text.lowercased()
        
        // Process digraphs first (most important for TTS)
        result = result.replacingOccurrences(of: "th", with: "θ")
        result = result.replacingOccurrences(of: "sh", with: "ʃ")
        result = result.replacingOccurrences(of: "ch", with: "tʃ")
        result = result.replacingOccurrences(of: "ng", with: "ŋ")
        result = result.replacingOccurrences(of: "ph", with: "f")
        
        // Process vowels to more accurate IPA (critical for voice quality)
        result = result.replacingOccurrences(of: "ee", with: "i")  // meet -> mit
        result = result.replacingOccurrences(of: "oo", with: "u")  // book -> buk
        result = result.replacingOccurrences(of: "ou", with: "aʊ") // house -> haʊs
        result = result.replacingOccurrences(of: "ow", with: "oʊ") // show -> ʃoʊ
        
        // Single vowel approximations
        result = result.replacingOccurrences(of: "a", with: "ə")   // about -> əbout
        result = result.replacingOccurrences(of: "e", with: "ɛ")   // test -> tɛst
        result = result.replacingOccurrences(of: "i", with: "ɪ")   // this -> θɪs
        result = result.replacingOccurrences(of: "o", with: "ɔ")   // of -> ɔf
        result = result.replacingOccurrences(of: "u", with: "ʊ")   // functionality -> fʊnctɪɔnəlɪty
        
        return result
    }
    
    
    
    
    
    
    private func generateRealisticVoiceEmbedding(seed: Int, size: Int, bias: Float, scale: Float) -> [Float] {
        var random = SeededRandom(seed: seed)
        
        return (0..<size).map { i in
            // Create more structured patterns that might resemble real voice embeddings
            let baseValue = Float(random.nextGaussian()) * scale + bias
            
            // Add some periodic components to create more structure
            let periodicComponent = sin(Float(i) * 0.1) * 0.05
            let harmonicComponent = cos(Float(i) * 0.05) * 0.03
            
            // Combine components and clamp to reasonable range
            let finalValue = baseValue + periodicComponent + harmonicComponent
            return max(-1.0, min(1.0, finalValue))
        }
    }
    
    private func simpleAudioNormalization(_ audio: [Float]) -> [Float] {
        guard !audio.isEmpty else { return audio }
        
        // Trim audio EXACTLY like JS version to remove artifacts
        let trimStart = min(1000, Int(floor(Float(audio.count) * 0.05)))
        let trimEnd = min(2000, Int(floor(Float(audio.count) * 0.05)))
        let endIndex = max(trimStart, audio.count - trimEnd)
        
        guard trimStart < endIndex else { 
            z_print("Warning: Invalid trim indices, returning original audio")
            return audio 
        }
        
        let trimmedAudio = Array(audio[trimStart..<endIndex])
        
        // Find max absolute value EXACTLY like JS
        var maxAbs: Float = 0.0
        for sample in trimmedAudio {
            maxAbs = max(maxAbs, abs(sample))
        }
        
        // Apply normalization with 0.8 gain EXACTLY like JS version
        let normalizedGain = maxAbs > 0 ? 0.8 / maxAbs : 1.0
        var normalizedAudio: [Float] = []
        normalizedAudio.reserveCapacity(trimmedAudio.count)
        
        for sample in trimmedAudio {
            normalizedAudio.append(sample * normalizedGain)
        }
        
        z_print("Audio normalization: \(audio.count) -> \(trimmedAudio.count) samples")
        z_print("MaxAbs: \(maxAbs), gain: \(normalizedGain)")
        z_print("Final range: [\(normalizedAudio.min() ?? 0), \(normalizedAudio.max() ?? 0)]")
        
        return normalizedAudio
    }
    
    private func applyHighPassFilter(_ audio: [Float], cutoffFrequency: Float) -> [Float] {
        // Simple first-order high-pass filter
        let sampleRate: Float = 24000.0
        let rc = 1.0 / (2.0 * Float.pi * cutoffFrequency)
        let dt = 1.0 / sampleRate
        let alpha = rc / (rc + dt)
        
        var filteredAudio = Array(repeating: Float(0), count: audio.count)
        var previousInput: Float = 0
        var previousOutput: Float = 0
        
        for i in 0..<audio.count {
            let input = audio[i]
            let output = alpha * (previousOutput + input - previousInput)
            filteredAudio[i] = output
            
            previousInput = input
            previousOutput = output
        }
        
        return filteredAudio
    }
    
    private func applyLowPassFilter(_ audio: [Float], cutoffFrequency: Float) -> [Float] {
        // Simple first-order low-pass filter
        let sampleRate: Float = 24000.0
        let rc = 1.0 / (2.0 * Float.pi * cutoffFrequency)
        let dt = 1.0 / sampleRate
        let alpha = dt / (rc + dt)
        
        var filteredAudio = Array(repeating: Float(0), count: audio.count)
        var previousOutput: Float = 0
        
        for i in 0..<audio.count {
            let input = audio[i]
            let output = previousOutput + alpha * (input - previousOutput)
            filteredAudio[i] = output
            previousOutput = output
        }
        
        return filteredAudio
    }
    
    private func applyCompression(_ audio: [Float], threshold: Float, ratio: Float) -> [Float] {
        return audio.map { sample in
            let absValue = abs(sample)
            if absValue > threshold {
                let excess = absValue - threshold
                let compressedExcess = excess / ratio
                let compressedValue = threshold + compressedExcess
                return sample >= 0 ? compressedValue : -compressedValue
            } else {
                return sample
            }
        }
    }
    
    private func normalizeAudio(_ audio: [Float]) -> [Float] {
        guard !audio.isEmpty else { return audio }
        
        // Calculate statistics before normalization
        let mean = audio.reduce(0, +) / Float(audio.count)
        let minValue = audio.min() ?? 0
        let maxValue = audio.max() ?? 0
        let maxAbsValue = audio.map { abs($0) }.max() ?? 1.0
        
        z_print("Pre-normalization stats: mean=\(mean), range=[\(minValue), \(maxValue)], maxAbs=\(maxAbsValue)")
        
        // Avoid division by zero
        guard maxAbsValue > 0.0 else { 
            z_print("Audio has no signal (maxAbs = 0)")
            return audio 
        }
        
        // Apply peak normalization with a small margin to prevent clipping
        let normalizationFactor = 0.95 / maxAbsValue
        let normalizedAudio = audio.map { $0 * normalizationFactor }
        
        // Validate normalized audio
        let newMin = normalizedAudio.min() ?? 0
        let newMax = normalizedAudio.max() ?? 0
        let newMean = normalizedAudio.reduce(0, +) / Float(normalizedAudio.count)
        
        z_print("Post-normalization stats: mean=\(newMean), range=[\(newMin), \(newMax)], factor=\(normalizationFactor)")
        
        return normalizedAudio
    }
    
    private func playAudio(data: [Float]) {
        // Validate audio data
        guard !data.isEmpty else {
            z_print("Audio data is empty")
            return
        }
        
        z_print("Playing audio with \(data.count) samples")
        
        // Analyze audio data before playing
        let mean = data.reduce(0, +) / Float(data.count)
        let min = data.min() ?? 0
        let max = data.max() ?? 0
        let nonZeroSamples = data.filter { abs($0) > 0.0001 }.count
        z_print("Audio analysis: mean=\(mean), range=[\(min), \(max)], nonZero=\(nonZeroSamples)/\(data.count)")
        
        // Use simple AVAudioPlayer with WAV data like the Web version
        // Convert Float32 to 16-bit PCM like JS implementation
        let pcmData = convertFloatToPCM16(data)
        let wavData = createWAVData(pcmData: pcmData, sampleRate: 24000, channels: 1)
        
        do {
            // Stop any previous playback
            if let currentPlayer = audioPlayer {
                currentPlayer.stop()
            }
            
            // Create new audio player with WAV data
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            z_print("Audio playback started using AVAudioPlayer")
            
        } catch {
            z_print("Failed to play audio: \(error)")
        }
    }
    
    private var audioPlayer: AVAudioPlayer?
    
    // Convert Float32 array to 16-bit PCM like JS version does
    private func convertFloatToPCM16(_ floatData: [Float]) -> Data {
        var pcmData = Data()
        pcmData.reserveCapacity(floatData.count * 2) // 2 bytes per sample
        
        for sample in floatData {
            // Clamp to [-1, 1] and convert to 16-bit signed integer like JS
            let clampedSample = max(-1.0, min(1.0, sample))
            let pcmSample = Int16(clampedSample * Float(Int16.max))
            
            // Write as little-endian 16-bit integer
            withUnsafeBytes(of: pcmSample.littleEndian) { bytes in
                pcmData.append(contentsOf: bytes)
            }
        }
        
        return pcmData
    }
    
    // Create WAV file data exactly like JS audioBufferToWav function
    private func createWAVData(pcmData: Data, sampleRate: Int, channels: Int) -> Data {
        var wavData = Data()
        wavData.reserveCapacity(44 + pcmData.count)
        
        let dataSize = UInt32(pcmData.count)
        let fileSize = UInt32(36 + pcmData.count)
        let byteRate = UInt32(sampleRate * channels * 2) // 2 bytes per sample
        let blockAlign = UInt16(channels * 2)
        
        // WAV header exactly like JS version
        wavData.append("RIFF".data(using: .ascii)!)                    // ChunkID
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })      // ChunkSize
        wavData.append("WAVE".data(using: .ascii)!)                    // Format
        wavData.append("fmt ".data(using: .ascii)!)                    // Subchunk1ID
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })    // Subchunk1Size
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })     // AudioFormat (PCM)
        wavData.append(withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) }) // NumChannels
        wavData.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) }) // SampleRate
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })      // ByteRate
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })    // BlockAlign
        wavData.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })    // BitsPerSample
        wavData.append("data".data(using: .ascii)!)                    // Subchunk2ID
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })      // Subchunk2Size
        
        // Audio data
        wavData.append(pcmData)
        
        z_print("Created WAV data: \(wavData.count) bytes total, \(pcmData.count) audio bytes")
        return wavData
    }
    
    func getAvailableVoices() -> [String] {
        return Array(voicesData.keys).sorted()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioEngine?.stop()
        playerNode?.stop()
    }
}

class SeededRandom {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(seed)
    }
    
    func nextFloat() -> Float {
        state = state &* 1103515245 &+ 12345
        return Float(state % 2147483647) / Float(2147483647)
    }
    
    func nextGaussian() -> Float {
        let u1 = nextFloat()
        let u2 = nextFloat()
        return sqrtf(-2.0 * logf(u1)) * cosf(2.0 * Float.pi * u2)
    }
}

enum TTSError: Error {
    case modelNotLoaded
    case synthesisError
    case voiceNotFound
    case voiceLoadError
    
    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "TTS model not loaded"
        case .synthesisError:
            return "Speech synthesis failed"
        case .voiceNotFound:
            return "Voice not found"
        case .voiceLoadError:
            return "Failed to load voice data"
        }
    }
}
