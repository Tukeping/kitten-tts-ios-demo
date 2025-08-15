//
//  TTSDemoVC.swift
//  kitten-tts-ios-demo
//
//  Created by FredTu on 2025-08-15
//

import UIKit

class TTSDemoVC: BaseVC {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let textView = UITextView()
    private let voiceSelectionLabel = UILabel()
    private let voicePickerView = UIPickerView()
    private let loadModelButton = UIButton(type: .system)
    private let generateButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    
    private var availableVoices: [String] = []
    private var selectedVoiceIndex = 0
    private var isModelLoaded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        
        title = "TTS Demo"
        
        // Initialize voices
        updateAvailableVoices()
    }
    
    private func updateAvailableVoices() {
        availableVoices = TTSManager.shared.getAvailableVoices()
        
        // Reload picker view
        voicePickerView.reloadAllComponents()
        
        // Select default voice if available
        if !availableVoices.isEmpty {
            if let defaultIndex = availableVoices.firstIndex(of: "expr-voice-2-f") {
                selectedVoiceIndex = defaultIndex
                voicePickerView.selectRow(defaultIndex, inComponent: 0, animated: false)
            } else {
                selectedVoiceIndex = 0
                voicePickerView.selectRow(0, inComponent: 0, animated: false)
            }
        }
        
        z_print("Updated available voices: \(availableVoices)")
    }
    
    
    private func setupUI() {
        view.backgroundColor = c_F4F8FC
        
        // Scroll view setup
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        
        scrollView.addSubview(contentView)
        
        // Title
        titleLabel.text = "TTS Model Testing"
        titleLabel.font = UIFont.adaptiveTitle
        titleLabel.textColor = c_122022
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        
        // Text input
        textView.text = "Hello, this is a test of the Text-to-Speech functionality."
        textView.font = UIFont.adaptiveBody
        textView.textColor = c_122022
        textView.backgroundColor = .white
        textView.layer.cornerRadius = view.adaptiveCornerRadius()
        textView.layer.borderWidth = 1
        textView.layer.borderColor = c_D1D5DB.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        contentView.addSubview(textView)
        
        // Voice selection label
        voiceSelectionLabel.text = "Select Voice:"
        voiceSelectionLabel.font = UIFont.adaptiveSubtitle
        voiceSelectionLabel.textColor = c_122022
        contentView.addSubview(voiceSelectionLabel)
        
        // Voice picker
        voicePickerView.backgroundColor = .white
        voicePickerView.layer.cornerRadius = view.adaptiveCornerRadius()
        voicePickerView.layer.borderWidth = 1
        voicePickerView.layer.borderColor = c_D1D5DB.cgColor
        voicePickerView.dataSource = self
        voicePickerView.delegate = self
        contentView.addSubview(voicePickerView)
        
        // Load Model button
        loadModelButton.setTitle("Load Model", for: .normal)
        loadModelButton.titleLabel?.font = UIFont.adaptiveSubtitle
        loadModelButton.setTitleColor(.white, for: .normal)
        loadModelButton.backgroundColor = c_95E80D
        loadModelButton.layer.cornerRadius = 12
        loadModelButton.layer.shadowColor = c_95E80D.cgColor
        loadModelButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        loadModelButton.layer.shadowRadius = 4
        loadModelButton.layer.shadowOpacity = 0.3
        contentView.addSubview(loadModelButton)
        
        // Generate button
        generateButton.setTitle("Generate Speech", for: .normal)
        generateButton.titleLabel?.font = UIFont.adaptiveSubtitle
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.backgroundColor = c_95E80D
        generateButton.layer.cornerRadius = 12
        generateButton.layer.shadowColor = c_95E80D.cgColor
        generateButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        generateButton.layer.shadowRadius = 4
        generateButton.layer.shadowOpacity = 0.3
        generateButton.isEnabled = false
        generateButton.alpha = 0.6
        contentView.addSubview(generateButton)
        
        // Stop button
        stopButton.setTitle("Stop Playback", for: .normal)
        stopButton.titleLabel?.font = UIFont.adaptiveSubtitle
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.backgroundColor = c_F6516F
        stopButton.layer.cornerRadius = 12
        stopButton.isEnabled = false
        stopButton.alpha = 0.6
        contentView.addSubview(stopButton)
        
        // Status label
        statusLabel.text = "Ready to generate speech"
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = c_6B7280
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        contentView.addSubview(statusLabel)
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        voiceSelectionLabel.translatesAutoresizingMaskIntoConstraints = false
        voicePickerView.translatesAutoresizingMaskIntoConstraints = false
        loadModelButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 120),
            
            voiceSelectionLabel.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 25),
            voiceSelectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            voicePickerView.topAnchor.constraint(equalTo: voiceSelectionLabel.bottomAnchor, constant: 10),
            voicePickerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            voicePickerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            voicePickerView.heightAnchor.constraint(equalToConstant: 120),
            
            loadModelButton.topAnchor.constraint(equalTo: voicePickerView.bottomAnchor, constant: 30),
            loadModelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            loadModelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            loadModelButton.heightAnchor.constraint(equalToConstant: 50),
            
            generateButton.topAnchor.constraint(equalTo: loadModelButton.bottomAnchor, constant: 15),
            generateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            generateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            generateButton.heightAnchor.constraint(equalToConstant: 50),
            
            stopButton.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 15),
            stopButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stopButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stopButton.heightAnchor.constraint(equalToConstant: 50),
            
            statusLabel.topAnchor.constraint(equalTo: stopButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    private func setupActions() {
        loadModelButton.addTarget(self, action: #selector(loadModelTapped), for: .touchUpInside)
        generateButton.addTarget(self, action: #selector(generateSpeechTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopPlaybackTapped), for: .touchUpInside)
        
        // Dismiss keyboard when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func loadModelTapped() {
        loadModelButton.isEnabled = false
        loadModelButton.alpha = 0.6
        statusLabel.text = "Loading model..."
        statusLabel.textColor = c_FDB022
        
        // Add loading animation
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = c_95E80D
        activityIndicator.startAnimating()
        loadModelButton.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.trailingAnchor.constraint(equalTo: loadModelButton.trailingAnchor, constant: -15),
            activityIndicator.centerYAnchor.constraint(equalTo: loadModelButton.centerYAnchor)
        ])
        
        TTSManager.shared.loadModelAsync { [weak self] success in
            DispatchQueue.main.async {
                activityIndicator.removeFromSuperview()
                
                if success {
                    self?.isModelLoaded = true
                    self?.loadModelButton.setTitle("Model Loaded ✓", for: .normal)
                    self?.loadModelButton.backgroundColor = c_94F658
                    self?.generateButton.isEnabled = true
                    self?.generateButton.alpha = 1.0
                    self?.statusLabel.text = "Model loaded successfully! Ready to generate speech."
                    self?.statusLabel.textColor = c_94F658
                    
                    // Update available voices after model loads
                    self?.updateAvailableVoices()
                } else {
                    self?.loadModelButton.isEnabled = true
                    self?.loadModelButton.alpha = 1.0
                    self?.statusLabel.text = "Failed to load model. Please try again."
                    self?.statusLabel.textColor = c_F6516F
                    self?.showAlert(title: "Model Loading Failed", message: "Failed to load the TTS model. Please check the model files and try again.")
                }
            }
        }
    }
    
    @objc private func generateSpeechTapped() {
        guard !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Error", message: "Please enter some text to generate speech.")
            return
        }
        
        guard isModelLoaded else {
            showAlert(title: "Error", message: "Please load the model first by tapping 'Load Model' button.")
            return
        }
        
        // Safety check for available voices
        guard !availableVoices.isEmpty && selectedVoiceIndex < availableVoices.count else {
            showAlert(title: "Error", message: "No voices available. Please wait for the model to load.")
            return
        }
        
        let selectedVoice = availableVoices[selectedVoiceIndex]
        
        // Update UI
        generateButton.isEnabled = false
        generateButton.alpha = 0.6
        stopButton.isEnabled = true
        stopButton.alpha = 1.0
        statusLabel.text = "Generating speech..."
        statusLabel.textColor = c_FDB022
        
        // Add loading animation
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = c_95E80D
        activityIndicator.startAnimating()
        generateButton.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.trailingAnchor.constraint(equalTo: generateButton.trailingAnchor, constant: -15),
            activityIndicator.centerYAnchor.constraint(equalTo: generateButton.centerYAnchor)
        ])
        
        z_print("Generating speech with text: '\(textView.text!)' and voice: '\(selectedVoice)'")
        
        TTSManager.shared.generateSpeech(text: textView.text, voiceName: selectedVoice) { [weak self] result in
            DispatchQueue.main.async {
                activityIndicator.removeFromSuperview()
                
                self?.generateButton.isEnabled = true
                self?.generateButton.alpha = 1.0
                
                switch result {
                case .success:
                    self?.statusLabel.text = "Speech generated and playing successfully!"
                    self?.statusLabel.textColor = c_94F658
                    
                    // Auto-enable stop button and disable generate during playback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self?.stopButton.isEnabled = false
                        self?.stopButton.alpha = 0.6
                        self?.statusLabel.text = "Ready to generate speech"
                        self?.statusLabel.textColor = c_6B7280
                    }
                    
                case .failure(let error):
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                    self?.statusLabel.textColor = c_F6516F
                    self?.stopButton.isEnabled = false
                    self?.stopButton.alpha = 0.6
                    
                    self?.showAlert(title: "Generation Failed", 
                                   message: "Failed to generate speech: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func stopPlaybackTapped() {
        TTSManager.shared.stopPlayback()
        
        stopButton.isEnabled = false
        stopButton.alpha = 0.6
        statusLabel.text = "Playback stopped"
        statusLabel.textColor = c_6B7280
    }
}

// MARK: - UIPickerViewDataSource & UIPickerViewDelegate
extension TTSDemoVC: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return availableVoices.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return availableVoices[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedVoiceIndex = row
        z_print("Selected voice: \(availableVoices[row])")
    }
}
