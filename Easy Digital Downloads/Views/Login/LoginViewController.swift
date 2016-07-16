//
//  LoginViewController.swift
//  Easy Digital Downloads
//
//  Created by Sunny Ratilal on 23/05/2016.
//  Copyright © 2016 Easy Digital Downloads. All rights reserved.
//

import UIKit
import CoreData
import Alamofire
import SwiftyJSON
import SSKeychain
import Gridicons
import SafariServices

class LoginViewController: UIViewController, UITextFieldDelegate, ManagedObjectContextSettable {
    
    var managedObjectContext: NSManagedObjectContext!
    var site: Site!
    
    var currencies = ["USD", "AFN", "ALL", "ANG", "ARS", "AUD", "AWG", "AZN", "BAM", "BBD", "BGN", "BMD", "BND", "BOB", "BRL", "BSD", "BWP", "BYR", "BZD", "CAD", "CHF", "CLP", "CNY", "COP", "CRC", "CUP", "CZK", "DKK", "DOP", "EEK", "EGP", "EUR", "FJD", "FKP", "GBP", "GGP", "GHC", "GIP", "GTQ", "GYD", "HKD", "HNL", "HRK", "HUF", "IDR", "ILS", "IMP", "INR", "IRR", "ISK", "JEP", "JMD", "JPY", "KGS", "KHR", "KPW", "KRW", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LTL", "LVL", "MKD", "MNT", "MUR", "MXN", "MYR", "MZN", "NAD", "NGN", "NIO", "NOK", "NPR", "NZD", "OMR", "PAB", "PEN", "PHP", "PKR", "PLN", "PYG", "QAR", "RON", "RSD", "RUB", "SAR", "SBD", "SCR", "SEK", "SGD", "SHP", "SOS", "SRD", "SVC", "SYP", "THB", "TRL", "TRY", "TTD", "TVD", "TWD", "UAH", "UYU", "UZS", "VEF", "VND", "XCD", "YER", "ZAR", "ZWD"]
    var types = ["Standard", "Commission Only", "Standard & Commission", "Standard & Store"]

    var currencyPickerView = UIPickerView()
    var typePickerView = UIPickerView()

    let logo = UIImageView(image: UIImage(named: "EDDLogoText-White"))
    let helpButton = UIButton(type: .Custom)
    let siteName = LoginTextField()
    let siteURL = LoginTextField()
    let apiKey = LoginTextField()
    let token = LoginTextField()
    let connectionTest = UILabel()
    
    let addButton = LoginSubmitButton()

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.appearance()
        
        let textFields = [siteName, siteURL, apiKey, token]
        
        var index = 0;
        
        logo.transform = CGAffineTransformMakeTranslation(0, -200)
        helpButton.transform = CGAffineTransformMakeTranslation(200, 0)
        addButton.layer.opacity = 0
        
        UIView.animateWithDuration(1.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.logo.transform = CGAffineTransformMakeTranslation(0, 0);
            self.helpButton.transform = CGAffineTransformMakeTranslation(0, 0)
            }, completion: nil)
        
        for field in textFields {
            let field: LoginTextField = field as LoginTextField
            field.layer.opacity = 0
            field.transform = CGAffineTransformMakeTranslation(0, 50)
            UIView.animateWithDuration(1.5, delay: 0.1 * Double(index), usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
                field.transform = CGAffineTransformMakeTranslation(0, 0);
                field.layer.opacity = 1
                }, completion: nil)
            index += 1
        }
        
        UIView.animateWithDuration(1.0, delay: 0.6, options: [], animations: {
            self.addButton.layer.opacity = 1
            }, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logo.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin]
        logo.contentMode = .ScaleAspectFit
        logo.heightAnchor.constraintEqualToConstant(100).active = true
        
        helpButton.sizeToFit()
        helpButton.accessibilityLabel = NSLocalizedString("Help", comment: "Help button")
        helpButton.addTarget(self, action: #selector(LoginViewController.handleHelpButtonTapped(_:)), forControlEvents: .TouchUpInside)
        helpButton.setImage(Gridicon.iconOfType(.Help, withSize: CGSizeMake(20, 20)), forState: .Normal)
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.tintColor = .EDDBlueColor()

        view.addSubview(helpButton)
        
        let margins = view.layoutMarginsGuide
        helpButton.topAnchor.constraintEqualToAnchor(topLayoutGuide.bottomAnchor, constant: 8).active = true
        helpButton.trailingAnchor.constraintEqualToAnchor(margins.trailingAnchor).active = true
        
        siteName.tag = 1
        siteName.placeholder = NSLocalizedString("Site Name", comment: "")
        siteName.delegate = self
        siteName.accessibilityIdentifier = "Site Name"
        
        siteURL.tag = 2
        siteURL.placeholder = NSLocalizedString("Site URL", comment: "")
        siteURL.delegate = self
        siteURL.accessibilityIdentifier = "Site URL"
        siteURL.autocapitalizationType = .None
        siteURL.keyboardType = .URL
        
        apiKey.tag = 3
        apiKey.placeholder = NSLocalizedString("API Key", comment: "")
        apiKey.delegate = self
        apiKey.accessibilityIdentifier = "API Key"
        apiKey.autocapitalizationType = .None
        
        token.tag = 4
        token.placeholder = NSLocalizedString("Token", comment: "")
        token.delegate = self
        token.accessibilityIdentifier = "Token"
        
        addButton.addTarget(self, action: #selector(LoginViewController.addButtonPressed(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        addButton.setTitle("Add Site", forState: UIControlState.Normal)
        addButton.setTitleColor(.whiteColor(), forState: UIControlState.Normal)
        addButton.setTitleColor(.whiteColor(), forState: UIControlState.Highlighted)
        addButton.backgroundColor = .EDDBlueColor()
        addButton.layer.cornerRadius = 2
        addButton.layer.opacity = 0.3
        addButton.clipsToBounds = true
        addButton.enabled = false
        
        connectionTest.textColor = .whiteColor()
        connectionTest.text = "Connecting to " + siteName.text! + "..."
        connectionTest.textAlignment = .Center
        connectionTest.hidden = true
        
        let buttonSpacerView = UIView()
        buttonSpacerView.heightAnchor.constraintEqualToConstant(20).active = true
        
        let labelSpacerView = UIView()
        labelSpacerView.heightAnchor.constraintEqualToConstant(20).active = true
        
        let stackView = UIStackView()
        stackView.axis = .Vertical
        stackView.distribution = .Fill
        stackView.alignment = .Fill
        stackView.spacing = 0
        
        stackView.addArrangedSubview(logo)
        stackView.addArrangedSubview(siteName)
        stackView.addArrangedSubview(siteURL)
        stackView.addArrangedSubview(apiKey)
        stackView.addArrangedSubview(token)
        stackView.addArrangedSubview(buttonSpacerView)
        stackView.addArrangedSubview(addButton)
        stackView.addArrangedSubview(labelSpacerView)
        stackView.addArrangedSubview(connectionTest)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.layoutMarginsRelativeArrangement = true
        
        view.addSubview(stackView)
        
        stackView.centerXAnchor.constraintEqualToAnchor(view.centerXAnchor).active = true
        stackView.centerYAnchor.constraintEqualToAnchor(view.centerYAnchor).active = true
        stackView.leadingAnchor.constraintEqualToAnchor(view.leadingAnchor, constant: 25).active = true
        stackView.trailingAnchor.constraintEqualToAnchor(view.trailingAnchor, constant: -25).active = true
    }
    
    func fillInFields(components: [NSURLQueryItem]) {
        for item in components {
            if item.name == "siteurl" {
                siteURL.text = item.value
            }
            
            if item.name == "sitename" {
                siteName.text = item.value
            }
            
            if item.name == "key" {
                apiKey.text = item.value
            }
            
            if item.name == "token" {
                token.text = item.value
            }
            
        }
    }
    
    func appearance() {
        view.backgroundColor = UIColor.EDDBlackColor()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    // MARK: UITextFieldDelegate
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        if textField.tag == 5 || textField.tag == 6 {
            return false
        }
        
        return true
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        validateInputs()
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        let textField = textField as! LoginTextField
        
        guard ( textField.tag == 2 && canOpenURL(textField.text) ) ||
              ( textField.tag != 2 && textField.hasText() ) else {
            textField.validated(false)
            return
        }
        
        textField.validated(true)

        validateInputs()
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        let nextTag = textField.tag + 1
        let nextResponder: UIResponder = (textField.superview?.viewWithTag(nextTag))!
        
        if nextResponder.canBecomeFirstResponder() && nextTag < 5 {
            nextResponder.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        
        return true
    }
    
    func validateInputs() {
        if siteName.hasText() && siteURL.hasText() && canOpenURL(siteURL.text) && apiKey.hasText() && token.hasText() {
            UIView.animateWithDuration(0.5, animations: {
                self.addButton.layer.opacity = 1
                self.addButton.enabled = true
            })
        } else {
            UIView.animateWithDuration(0.5, animations: {
                self.addButton.layer.opacity = 0.3
                self.addButton.enabled = false
            })
        }
    }

    // MARK: Button Handlers
    
    func handleHelpButtonTapped(sender: UIButton) {
        let svc = SFSafariViewController(URL: NSURL(string: "http://docs.easydigitaldownloads.com/article/1134-edd-rest-api---authentication")!)
        svc.modalPresentationStyle = .OverCurrentContext
        svc.view.tintColor = .EDDBlueColor()
        self.presentViewController(svc, animated: true, completion: nil)
    }
    
    func addButtonPressed(sender: UIButton!) {
        let button = sender as! LoginSubmitButton
        button.showActivityIndicator(true)
        
        connectionTest.text = "Connecting to " + siteName.text! + "..."
        
        let textFields = [siteName, siteURL, apiKey, token]
        
        for textField in textFields {
            textField.enabled = false
        }
        
        self.addButton.enabled = false
        
        UIView.animateWithDuration(0.5) {
            self.siteName.layer.opacity = 0.3
            self.siteURL.layer.opacity = 0.3
            self.apiKey.layer.opacity = 0.3
            self.token.layer.opacity = 0.3
            
            self.connectionTest.hidden = false
        }
        
        Alamofire.request(.GET, siteURL.text! + "/edd-api/info", parameters: ["key": apiKey.text!, "token": token.text!])
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .responseJSON { response in
                switch response.result {
                    case .Success:
                        let json = JSON(response.result.value!)
                        if json["info"] != nil {
                            let info = json["info"]
                            self.connectionTest.text = NSLocalizedString("Connection successful", comment: "")
                            let uid = NSUUID().UUIDString
                            
                            var hasReviews = false
                            var hasCommissions = false
                            var hasFES = false
                            var hasRecurring = false
                            
                            let integrations = info["integrations"]
                            for (key, value) : (String, JSON) in integrations {
                                if key == "reviews" && value.boolValue == true {
                                    hasReviews = true
                                }
                                
                                if key == "commissions" && value.boolValue == true {
                                    hasCommissions = true
                                }
                                
                                if key == "fes" && value.boolValue == true {
                                    hasFES = true
                                }
                                
                                if key == "recurring" && value.boolValue == true {
                                    hasRecurring = true
                                }
                            }
                            
                            let currency = "\(info["currency"])"
                            
                            SSKeychain.setPassword(self.token.text, forService: uid, account: self.apiKey.text)
                            
                            // Only set the defaultSite if this is the first site being added
                            let appDelegate = AppDelegate()
                            if appDelegate.noSitesSetup() {
                                NSUserDefaults.standardUserDefaults().setValue(uid, forKey: "defaultSite")
                                NSUserDefaults.standardUserDefaults().synchronize()
                            }
                            
                            var site: Site?
                            
                            self.managedObjectContext.performChanges {
                                site = Site.insertIntoContext(self.managedObjectContext, uid: uid, name: self.siteName.text!, url: self.siteURL.text!, currency: currency, hasCommissions: hasCommissions, hasFES: hasFES, hasRecurring: hasRecurring, hasReviews: hasReviews)
                                self.managedObjectContext.performSaveOrRollback()
                            }

                            UIView.animateWithDuration(1.0, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
                                self.logo.transform = CGAffineTransformMakeTranslation(0, -200)
                                self.addButton.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.height)
                                self.helpButton.transform = CGAffineTransformMakeTranslation(200, 0)
                                self.connectionTest.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.height)
                                for field in textFields {
                                    field.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.height)
                                }
                                }, completion: { (finished: Bool) -> Void in
                                    let tabBarController = SiteTabBarController(site: site!)
                                    tabBarController.modalPresentationStyle = .OverCurrentContext
                                    self.presentViewController(tabBarController, animated: true, completion:nil)
                            })
                        }
                        break;
                    case .Failure(let error):
                        NSLog(error.localizedDescription)
                        dispatch_async(dispatch_get_main_queue(), {
                            self.connectionTest.text = NSLocalizedString("Connection failed", comment: "")
                            for textField in textFields {
                                textField.enabled = true
                                textField.layer.opacity = 1
                            }
                            
                            button.showActivityIndicator(false)
                        })
                        break;
                }
        }
    }
    
    // MARK: Validation

    func canOpenURL(string: String?) -> Bool {
        guard let urlString = string?.stringByRemovingPercentEncoding! else {return false}
        guard let url = NSURL(string: urlString) else {return false}
        if !UIApplication.sharedApplication().canOpenURL(url) {return false}

        let regEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        return NSPredicate(format: "SELF MATCHES %@", regEx).evaluateWithObject(urlString)
    }

}
