// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import AVFoundation
import UIKit

protocol QRScanViewControllerDelegate: AnyObject {
    func addScannedQRCode(tunnelConfiguration: TunnelConfiguration, qrScanViewController: QRScanViewController, completionHandler: (() -> Void)?)
}

class QRScanViewController: UIViewController {
    weak var delegate: QRScanViewControllerDelegate?
    var captureSession: AVCaptureSession? = AVCaptureSession()
    let metadataOutput = AVCaptureMetadataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = tr("scanQRCodeViewTitle")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        let tipLabel = UILabel()
        tipLabel.text = tr("scanQRCodeTipText")
        tipLabel.adjustsFontSizeToFitWidth = true
        tipLabel.textColor = .lightGray
        tipLabel.textAlignment = .center

        view.addSubview(tipLabel)
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tipLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tipLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tipLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
            let captureSession = captureSession,
            captureSession.canAddInput(videoInput),
            captureSession.canAddOutput(metadataOutput) else {
                scanDidEncounterError(title: tr("alertScanQRCodeCameraUnsupportedTitle"), message: tr("alertScanQRCodeCameraUnsupportedMessage"))
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
            let currentDevice = UIDevice.current
            let orientation = currentDevice.orientation
            let previewLayerConnection = connection

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

        previewLayer?.frame = view.bounds
    }

    func scanDidComplete(withCode code: String) {
        let scannedTunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: code, called: "Scanned")
        guard let tunnelConfiguration = scannedTunnelConfiguration else {
            scanDidEncounterError(title: tr("alertScanQRCodeInvalidQRCodeTitle"), message: tr("alertScanQRCodeInvalidQRCodeMessage"))
            return
        }

        let alert = UIAlertController(title: tr("alertScanQRCodeNamePromptTitle"), message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: tr("actionCancel"), style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        })
        alert.addAction(UIAlertAction(title: tr("actionSave"), style: .default) { [weak self] _ in
            guard let title = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return }
            tunnelConfiguration.name = title
            if let self = self {
                self.delegate?.addScannedQRCode(tunnelConfiguration: tunnelConfiguration, qrScanViewController: self) {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        })
        present(alert, animated: true)
    }

    func scanDidEncounterError(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: tr("actionOK"), style: .default) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        })
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
                scanDidEncounterError(title: tr("alertScanQRCodeUnreadableQRCodeTitle"), message: tr("alertScanQRCodeUnreadableQRCodeMessage"))
                return
        }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        scanDidComplete(withCode: stringValue)
    }
}
