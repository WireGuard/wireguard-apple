// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import AVFoundation
import CoreData
import UIKit

protocol QRScanViewControllerDelegate: class {
    func addScannedQRCode(tunnelConfiguration: TunnelConfiguration, qrScanViewController: QRScanViewController, completionHandler: (() -> Void)?)
}

class QRScanViewController: UIViewController {
    weak var delegate: QRScanViewControllerDelegate?
    var captureSession: AVCaptureSession? = AVCaptureSession()
    let metadataOutput = AVCaptureMetadataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Scan QR code"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        let tipLabel = UILabel()
        tipLabel.text = "Tip: Generate with `qrencode -t ansiutf8 < tunnel.conf`"
        tipLabel.adjustsFontSizeToFitWidth = true
        tipLabel.textColor = UIColor.lightGray
        tipLabel.textAlignment = .center

        view.addSubview(tipLabel)
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tipLabel.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            tipLabel.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor),
            tipLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            ])

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
            let captureSession = captureSession,
            captureSession.canAddInput(videoInput),
            captureSession.canAddOutput(metadataOutput) else {
                scanDidEncounterError(title: "Camera Unsupported", message: "This device is not able to scan QR codes")
                return
        }

        captureSession.addInput(videoInput)
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if captureSession?.isRunning == false {
            captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let connection = previewLayer?.connection {

            let currentDevice: UIDevice = UIDevice.current

            let orientation: UIDeviceOrientation = currentDevice.orientation

            let previewLayerConnection: AVCaptureConnection = connection

            if previewLayerConnection.isVideoOrientationSupported {

                switch orientation {
                case .portrait:
                    previewLayerConnection.videoOrientation = .portrait
                case .landscapeRight:
                    previewLayerConnection.videoOrientation = .landscapeLeft
                case .landscapeLeft:
                    previewLayerConnection.videoOrientation = .landscapeRight
                case .portraitUpsideDown:
                    previewLayerConnection.videoOrientation = .portraitUpsideDown
                default:
                    previewLayerConnection.videoOrientation = .portrait

                }
            }
        }

        previewLayer?.frame = self.view.bounds
    }

    func scanDidComplete(withCode code: String) {
        let scannedTunnelConfiguration = try? WgQuickConfigFileParser.parse(code, name: "Scanned")
        guard let tunnelConfiguration = scannedTunnelConfiguration else {
            scanDidEncounterError(title: "Invalid QR Code", message: "The scanned QR code is not a valid WireGuard configuration")
            return
        }

        let alert = UIAlertController(title: NSLocalizedString("Please name the scanned tunnel", comment: ""), message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .default, handler: { [weak self] _ in
            let title = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if (title.isEmpty) { return }
            tunnelConfiguration.interface.name = title
            if let s = self {
                s.delegate?.addScannedQRCode(tunnelConfiguration: tunnelConfiguration, qrScanViewController: s) {
                    s.dismiss(animated: true, completion: nil)
                }
            }
        }))
        present(alert, animated: true)
    }

    func scanDidEncounterError(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        present(alertController, animated: true)
        captureSession = nil
    }

    @objc func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
}

extension QRScanViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession?.stopRunning()

        guard let metadataObject = metadataObjects.first,
            let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
            let stringValue = readableObject.stringValue else {
                scanDidEncounterError(title: "Invalid Code", message: "The scanned code could not be read")
                return
        }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        scanDidComplete(withCode: stringValue)
    }
}
