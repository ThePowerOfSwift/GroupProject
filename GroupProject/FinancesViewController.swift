//
//  FinancesViewController.swift
//  GroupProject
//
//  Created by Brandon Aubrey on 4/24/17.
//  Copyright © 2017 Brandon Aubrey. All rights reserved.
//

import UIKit

class FinancesViewController: DashBaseViewController, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var sourceImageView: UIImageView!
    @IBOutlet weak var sourceCurrencyCodeLabel: UILabel!
    @IBOutlet weak var sourceCurrencyNameLabel: UILabel!
    @IBOutlet weak var sourceAmountField: UITextField!

    @IBOutlet weak var targetImageView: UIImageView!
    @IBOutlet weak var targetCurrencyCodeLabel: UILabel!
    @IBOutlet weak var targetCurrencyNameLabel: UILabel!
    @IBOutlet weak var targetAmountField: UITextField!

    @IBOutlet weak var scrollView: UIScrollView!

    var receiptSource: ReceiptSource = .manual

    fileprivate var activityIndicator:UIActivityIndicatorView!

    fileprivate var currencyConverterTimer = Timer()
    fileprivate var currencyConverter: CurrencyConverter!
    fileprivate var importedReceiptImageURL: URL?

    // Setups up action buttons for adding receipts - Quick Import via Camera or Manually create receipt
    override var floatingActionButtons: [UIButton] {
        let buttonFrame = CGRect(x: 0, y: 0, width: 66, height: 66)

        let camera = UIButton(frame: buttonFrame)
        camera.addTarget(self, action: #selector(importImage(_:)), for: .touchUpInside)
        camera.setImage(UIImage(named:"cbutton_camera"), for: .normal)
        camera.setImage(UIImage(named:"cbutton_camera-tap"), for: .highlighted)

        let manual = UIButton(frame: buttonFrame)
        manual.addTarget(self, action: #selector(createReceipt(_:)), for: .touchUpInside)
        manual.setImage(UIImage(named:"cbutton_pencil"), for: .normal)
        manual.setImage(UIImage(named:"cbutton_pencil-tap"), for: .highlighted)

        return [camera, manual]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup custom page control
        let newPageControl = CustomSegmentedControl(frame: CGRect(x: 0, y: 0, width: 450, height: scrollView.frame.height))
        newPageControl.items = ["Expense Report","Denomination Guide","Nearby Exchanges"]
        newPageControl.backColor = .yellow
        newPageControl.cornerRadius = 0
        newPageControl.bottomBorderEnabled = true
        newPageControl.highlightedLabelColor = .red
        newPageControl.unSelectedLabelColor = .black
        newPageControl.fontSize = 14.0
        newPageControl.radiusStyle = false
        newPageControl.flatStyle = true
        newPageControl.selectedLabelViewColor = .red
        newPageControl.selectedLabelBorderWidth = 0
        newPageControl.addTarget(self, action: #selector(pageControlValueChanged(_:)), for: .valueChanged)

        // Setup scrollview for page control
        scrollView.contentSize = newPageControl.frame.size
        scrollView.addSubview(newPageControl)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isScrollEnabled = false

        // TODO: Setup source and target fields dynamically based on the user's current and native locations.
        let currentUser = User.sharedInstance
        setupCurrencyConverter(localCurrencyCd: currentUser.destinationCurrency ?? "USD", localCountry: currentUser.destinationCountry ?? "United States", nativeCurrencyCd: currentUser.nativeCurrency ?? "USD", nativeCountry: currentUser.nativeCountry ?? "United States")
    }

    // MARK: Page Control

    func pageControlValueChanged(_ sender: Any){
        // Force cast is OK here.
        let pageControl = sender as! CustomSegmentedControl
        // Figure out the new rect to display based on selected index
        let labelWidthWithPadding: CGFloat = 200
        let xPosition = CGFloat(pageControl.selectedIndex) * labelWidthWithPadding
        let rectToDisplay = CGRect(x: xPosition, y: 0, width: labelWidthWithPadding, height: scrollView.frame.height)
        // Scroll to new recet
        scrollView.scrollRectToVisible(rectToDisplay, animated: true)
    }

    // MARK: Model Setup

    func setupCurrencyConverter(localCurrencyCd: String, localCountry: String, nativeCurrencyCd: String, nativeCountry: String) {
        currencyConverter = CurrencyConverter(localCurrencyCd: localCurrencyCd, localCountry: localCountry, nativeCurrencyCd: nativeCurrencyCd, nativeCountry: nativeCountry)
        currencyConverter.updateCurrencyConversionFactors {[weak self] (result) in

            DispatchQueue.main.async {
                if result.isSuccess {
                    self?.updateUI(isInteractive: false)
                } else {
                    // TODO: Throw UI alert
                    // Display UI alert, if needed...
                    print("error: \(String(describing: result.error?.localizedDescription))")
                }
            }
        }
    }

    // MARK: View Updates

    func updateUI(isInteractive: Bool) {

        switch currencyConverter.conversionMode {

        case .localToNative:
            sourceImageView.image = UIImage(named: "USD")
            sourceCurrencyCodeLabel.text = currencyConverter.localCurrencyCode
            sourceCurrencyNameLabel.text = currencyConverter.localCountry

            if isInteractive == false {
                sourceAmountField.text = String(format: "%.2f", currencyConverter.localCurrencyAmount)
            }

            targetImageView.image = UIImage(named: "JPY")
            targetCurrencyCodeLabel.text = currencyConverter.nativeCurrencyCode
            targetCurrencyNameLabel.text = currencyConverter.nativeCountry
            targetAmountField.text = String(format: "%.2f", currencyConverter.nativeCurrencyAmount)

        case .nativeToLocal:
            sourceImageView.image = UIImage(named: "JPY")
            sourceCurrencyCodeLabel.text = currencyConverter.nativeCurrencyCode
            sourceCurrencyNameLabel.text = currencyConverter.nativeCountry

            if isInteractive == false {
                sourceAmountField.text = String(format: "%.2f", currencyConverter.nativeCurrencyAmount)
            }

            targetImageView.image = UIImage(named: "USD")
            targetCurrencyCodeLabel.text = currencyConverter.localCurrencyCode
            targetCurrencyNameLabel.text = currencyConverter.localCountry
            targetAmountField.text = String(format: "%.2f", currencyConverter.localCurrencyAmount)
        }
    }

    // MARK: Action Methods

    @IBAction func toggleSourceTargetCurrencies(_ sender: Any) {
        // Toggle the conversion mode
        currencyConverter.conversionMode.toggle()
        // Update the UI
        updateUI(isInteractive: false)
    }

    // UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        if textField.text?.characters.count == 0 && string == "" {
            textField.text = "1"
        }

        if textField == sourceAmountField {
            currencyConverterTimer.invalidate()
            currencyConverterTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false, block: { (_) in
                if let sourceAmountStr = textField.text, let sourceAmount = Double(sourceAmountStr) {
                    DispatchQueue.main.async {
                        switch self.currencyConverter.conversionMode {
                        case .localToNative:
                            self.currencyConverter.localCurrencyAmount = sourceAmount
                        case .nativeToLocal:
                            self.currencyConverter.nativeCurrencyAmount = sourceAmount
                        }
                        self.updateUI(isInteractive: true)
                    }
                }
            })
            return true

        } else {
            return false
        }
    }

    // MARK: Navigation

    func createReceipt(_ sender: AnyObject) {
        DispatchQueue.main.async {
            // Track receipt source
            self.receiptSource = .manual
            // Perform segue to create receipt view
            self.performSegue(withIdentifier: "CreateReceiptView", sender: sender)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "CreateReceiptView" {

            let destination = (segue.destination as! UINavigationController).topViewController as! CreateReceiptViewController

            destination.sourceType = receiptSource
            destination.source = currencyConverter
            destination.receiptImageURL = importedReceiptImageURL
        }
    }
}

extension FinancesViewController: UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        importedReceiptImageURL = info[UIImagePickerControllerReferenceURL] as? URL
        let selectedPhoto = info[UIImagePickerControllerOriginalImage] as! UIImage
        let scaledImage = scale(image: selectedPhoto, maxDimension: 640)

        addActivityIndicator()

        dismiss(animated:true, completion: {
            self.performImageRecognition(scaledImage)
        })
    }

    // Import currency amounts for conversion
    @IBAction func importImage(_ sender: AnyObject) {
        // End editing to discard keyboards or input views, if any
        view.endEditing(true)

        let imagePickerActionSheet = UIAlertController(title: "Snap/Upload Photo",
                                                       message: nil, preferredStyle: .actionSheet)

        // Check for device compabtability before adding Camera button
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePickerActionSheet.addAction(UIAlertAction(title: "Take Photo",
                                                           style: .default) { (alert) -> Void in
                                                            let imagePicker = UIImagePickerController()
                                                            imagePicker.delegate = self
                                                            imagePicker.sourceType = .camera
                                                            self.present(imagePicker,animated: true,completion: nil)
            })
        }

        // Option to pick existing images
        imagePickerActionSheet.addAction(UIAlertAction(title: "Choose Existing",
                                                       style: .default) { (alert) -> Void in
                                                        let imagePicker = UIImagePickerController()
                                                        imagePicker.delegate = self
                                                        imagePicker.sourceType = .photoLibrary
                                                        self.present(imagePicker,animated: true,completion: nil)
        })

        // Option to cancel the import action
        imagePickerActionSheet.addAction(UIAlertAction(title: "Cancel",
                                                       style: .cancel) { (alert) -> Void in
        })

        present(imagePickerActionSheet, animated: true, completion: nil)
    }

    // Tesseract conversion of image to text
    func performImageRecognition(_ image: UIImage) {

        let tesseract = G8Tesseract()

        tesseract.language = "eng+fra"
        tesseract.engineMode = .tesseractCubeCombined
        tesseract.pageSegmentationMode = .auto
        tesseract.maximumRecognitionTime = 60.0
        tesseract.image = image.g8_blackAndWhite()

        tesseract.recognize()

        let importedText = tesseract.recognizedText
        print("Imported Text: \(importedText ?? "No text imported")")
        createReceipt(forImportedLocalAmount: 36.14, localCurrencyCd: "USD", localCountry: "United States", nativeCurrencyCd: "JPY", nativeCountry: "Japan")

        removeActivityIndicator()
    }

    func createReceipt(forImportedLocalAmount localCurrencyAmount: Double, localCurrencyCd: String, localCountry: String, nativeCurrencyCd: String, nativeCountry: String) {
        currencyConverter = CurrencyConverter(localCurrencyCd: localCurrencyCd, localCountry: localCountry, nativeCurrencyCd: nativeCurrencyCd, nativeCountry: nativeCountry, localCurrencyAmount: localCurrencyAmount)
        currencyConverter.updateCurrencyConversionFactors {[weak self] (result) in

            DispatchQueue.main.async {
                if result.isSuccess {
                    self?.updateUI(isInteractive: false)
                    // Track receipt source
                    self?.receiptSource = .camera
                    // Initiate create new receipt segue
                    self?.performSegue(withIdentifier: "CreateReceiptView", sender: self)
                } else {
                    // TODO: Throw UI alert
                    // Display UI alert, if needed...
                    print("error: \(String(describing: result.error?.localizedDescription))")
                }
            }
        }
    }

    // Scaling image for better recognition
    func scale(image: UIImage, maxDimension: CGFloat) -> UIImage {

        var scaledSize = CGSize(width: maxDimension, height: maxDimension)
        var scaleFactor: CGFloat

        if image.size.width > image.size.height {
            scaleFactor = image.size.height / image.size.width
            scaledSize.width = maxDimension
            scaledSize.height = scaledSize.width * scaleFactor
        } else {
            scaleFactor = image.size.width / image.size.height
            scaledSize.height = maxDimension
            scaledSize.width = scaledSize.height * scaleFactor
        }

        UIGraphicsBeginImageContext(scaledSize)
        image.draw(in: CGRect(x: 0, y: 0, width: scaledSize.width, height: scaledSize.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return scaledImage
    }

    // Activity Progress indicators while processing image
    func addActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(frame: view.bounds)
        activityIndicator.activityIndicatorViewStyle = .whiteLarge
        activityIndicator.backgroundColor = UIColor(white: 0, alpha: 0.25)
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
    }

    func removeActivityIndicator() {
        activityIndicator.removeFromSuperview()
        activityIndicator = nil
    }
}
