import UIKit
import ARKit
import RealityKit

final class CombinedRecordingViewController: UIViewController, ARSessionDelegate {

    private let arView = ARView(frame: .zero)
    private let statusLabel = UILabel()
    private let startStopButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)

    private let recorder = CombinedSessionRecorder()

    private var isRecording = false
    private var exportURLs: [URL] = []
    private var selectedVideoFormat: ARConfiguration.VideoFormat?
    private var lidarAvailable = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Combined Recording"
        view.backgroundColor = .black
        setupUI()
        configureARSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            arView.session.pause()
        }
    }

    private func setupUI() {
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        statusLabel.text = "Ready"
        view.addSubview(statusLabel)

        startStopButton.translatesAutoresizingMaskIntoConstraints = false
        startStopButton.setTitle("Start", for: .normal)
        startStopButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        startStopButton.backgroundColor = .systemBlue
        startStopButton.setTitleColor(.white, for: .normal)
        startStopButton.layer.cornerRadius = 10
        startStopButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        startStopButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        view.addSubview(startStopButton)

        exportButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.setTitle("Export ZIP(s)", for: .normal)
        exportButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        exportButton.backgroundColor = .darkGray
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 10
        exportButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        exportButton.addTarget(self, action: #selector(shareExports), for: .touchUpInside)
        exportButton.isEnabled = false
        exportButton.alpha = 0.6
        view.addSubview(exportButton)

        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9),

            startStopButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            startStopButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            startStopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            exportButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            exportButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            exportButton.bottomAnchor.constraint(equalTo: startStopButton.topAnchor, constant: -12)
        ])
    }

    private func configureARSession() {
        guard ARBodyTrackingConfiguration.isSupported else {
            statusLabel.text = "Body tracking not supported on this device."
            startStopButton.isEnabled = false
            return
        }

        let config = ARBodyTrackingConfiguration()
        config.isLightEstimationEnabled = true
        lidarAvailable = ARBodyTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        if lidarAvailable {
            config.frameSemantics.insert(.sceneDepth)
        }

        if let format = selectPreferredVideoFormat() {
            config.videoFormat = format
            selectedVideoFormat = format
        }

        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        let resolutionText = selectedVideoFormat.map {
            "\(Int($0.imageResolution.width))x\(Int($0.imageResolution.height))"
        } ?? "default"
        let fpsText = selectedVideoFormat.map { "\($0.framesPerSecond)" } ?? "default"
        statusLabel.text = "Ready\nRGB: \(resolutionText) @ \(fpsText) FPS\nLiDAR in combined mode: \(lidarAvailable ? "yes" : "no")"
    }

    private func selectPreferredVideoFormat() -> ARConfiguration.VideoFormat? {
        let formats = ARBodyTrackingConfiguration.supportedVideoFormats
        if let exact = formats.first(where: { format in
            Int(format.imageResolution.width) == 1920 &&
            Int(format.imageResolution.height) == 1080 &&
            format.framesPerSecond >= 60
        }) {
            return exact
        }
        return formats.max { a, b in
            if a.framesPerSecond == b.framesPerSecond {
                return a.imageResolution.width * a.imageResolution.height < b.imageResolution.width * b.imageResolution.height
            }
            return a.framesPerSecond < b.framesPerSecond
        }
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let resolution = selectedVideoFormat?.imageResolution ?? arView.bounds.size
        let fps = selectedVideoFormat?.framesPerSecond ?? 60

        do {
            try recorder.prepareRecording(
                cameraResolution: resolution,
                videoFPS: fps,
                lidarAvailable: lidarAvailable
            )
        } catch {
            statusLabel.text = "Failed to prepare recording:\n\(error.localizedDescription)"
            return
        }

        exportURLs.removeAll()
        exportButton.isEnabled = false
        exportButton.alpha = 0.6
        isRecording = true
        startStopButton.setTitle("Stop", for: .normal)
        startStopButton.backgroundColor = .systemRed
        statusLabel.text = "Recording combined stream..."
    }

    private func stopRecording() {
        isRecording = false
        startStopButton.isEnabled = false
        statusLabel.text = "Finishing export..."

        recorder.finishRecording { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.startStopButton.isEnabled = true
                self.startStopButton.setTitle("Start", for: .normal)
                self.startStopButton.backgroundColor = .systemBlue

                switch result {
                case .success(let zipURLs):
                    self.exportURLs = zipURLs
                    self.exportButton.isEnabled = !zipURLs.isEmpty
                    self.exportButton.alpha = zipURLs.isEmpty ? 0.6 : 1
                    let names = zipURLs.map(\.lastPathComponent).joined(separator: "\n")
                    self.statusLabel.text = "Done\n\(names)"
                case .failure(let error):
                    self.statusLabel.text = "Combined export failed:\n\(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func shareExports() {
        guard !exportURLs.isEmpty else { return }
        let shareVC = UIActivityViewController(activityItems: exportURLs, applicationActivities: nil)
        present(shareVC, animated: true)
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRecording else { return }
        recorder.process(frame: frame)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard isRecording else { return }
        recorder.process(anchors: anchors, currentFrameTimestamp: session.currentFrame?.timestamp)
    }
}
