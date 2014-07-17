//
//  SignInViewController.swift
//  Illuminati
//
//  Created by Gosha Arinich on 7/16/14.
//  Copyright (c) 2014 Gosha Arinich. All rights reserved.
//

import UIKit
import QuartzCore

func stringsForMode(mode: String) -> [String: String] {
    switch mode {
    case "signIn":
        return [
            "button": "Sign In",
            "switch": "Don't have an account? Sign up →"
        ]
    default:
        return [
            "button": "Sign Up",
            "switch": "Already have an account? Sign in →"
        ]
    }
}

class SignInViewController: UITableViewController, UITextFieldDelegate {
    
    var mode = "signIn"
    
    let metrics = [
        "hmargin": 16,
        "vmargin": 10,
        "fvmargin": 5
    ]
    
    @lazy var headerLabel: UILabel = {
        let label = UILabel().noMask()
        label.text = "Welcome to Illuminati, an anonymous social network."
        label.numberOfLines = 0
        label.textAlignment = .Center
        label.textColor = UIColor.grayColor()
        label.font = UIFont.systemFontOfSize(11)
        return label
    }()
    
    @lazy var footerButton: UIButton = {
        let button = UIButton.borderedButton().noMask()
        
        return button
    }()
    
    @lazy var footerSwitchButton: UIButton = {
        let button = UIButton.buttonWithType(.System).noMask() as UIButton
        button.setTitleColor(UIColor.grayColor(), forState: .Normal)
        button.titleLabel.textAlignment = .Center
        button.titleLabel.font = UIFont.systemFontOfSize(10)
        
        return button
    }()
    
    @lazy var hw = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 30))
    @lazy var fw = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 80))
    
    @lazy var emailTextField: UITextField = {
        let field = UITextField().noMask()
        field.keyboardType = .EmailAddress
        field.autocapitalizationType = .None
        field.autocorrectionType = .No
        field.returnKeyType = .Next
        field.placeholder = "Email address"
        field.delegate = self
        return field
    }()
    
    @lazy var phoneTextField: UITextField = {
        let field = UITextField().noMask()
        field.keyboardType = .PhonePad
        field.returnKeyType = .Next
        field.placeholder = "Phone"
        field.delegate = self
        return field
        }()
    
    @lazy var passwordTextField: UITextField = {
        let field = UITextField().noMask()
        field.secureTextEntry = true
        field.returnKeyType = .Go
        field.placeholder = "Password"
        field.delegate = self
        return field
    }()
    
    var email: String { return self.emailTextField.text }
    var phone: String { return self.phoneTextField.text }
    var password: String { return self.passwordTextField.text }

    @lazy var validEmailSignal: RACSignal = self.emailTextField.rac_textSignal()
        .map { self.isValidEmail($0 as NSString) }
    @lazy var validPasswordSignal: RACSignal = self.passwordTextField.rac_textSignal()
        .map { self.isValidPassword($0 as NSString) }
    @lazy var validPhoneSignal: RACSignal = self.phoneTextField.rac_textSignal()
        .map { self.isValidPhone($0 as NSString) }
    @lazy var isSignInSignal: RACSignal = (self --> "mode").map { $0 as String == "signIn" }
    
    @lazy var validPhoneSignUpSignal: RACSignal = RACSignal
        .combineLatest([self.isSignInSignal, self.validPhoneSignal])
        .OR()
    
    @lazy var signInActiveSignal: RACSignal = RACSignal
        .combineLatest([self.validEmailSignal, self.validPhoneSignUpSignal, self.validPasswordSignal])
        .AND()
    
    var actionSignal: RACSignal {
        if self.mode == "signIn" {
            return UsersService.sharedService.signIn(self.email, password: self.password)
        } else {
            return UsersService.sharedService.signUp(self.email, phone: self.phone, password: self.password)
        }
    }
    
    @lazy var actionCommand: RACCommand = RACCommand(enabled: self.signInActiveSignal) { _ in
        return self.actionSignal
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Illuminati"
        
        tableView.separatorStyle = .None
        
        hw.addSubview(headerLabel)
        fw.addSubview(footerButton)
        fw.addSubview(footerSwitchButton)
        
        tableView.tableHeaderView = hw
        tableView.tableFooterView = fw
        
        layoutSubviews()
        
        footerButton.rac_command = actionCommand
        
        RAC(UIApplication.sharedApplication(), "networkActivityIndicatorVisible") <~ actionCommand.executing
        
        RAC(footerSwitchButton, "enabled") <~ actionCommand.executing.NOT()
        
        footerSwitchButton.addTarget(self, action: "toggleMode", forControlEvents: .TouchUpInside)
        
        actionCommand.executionSignals
            .flatten()
            .deliverOn(RACScheduler.mainThreadScheduler())
            .subscribeNext { _ in self.navigationController.dismissViewControllerAnimated(true, completion: nil) }
        
        actionCommand.errors
            .deliverOn(RACScheduler.mainThreadScheduler())
            .subscribeNext {
                let error = $0 as NSError
                let title = error.userInfo["title"] as? NSString
                let message = error.userInfo["message"] as? NSString
                UIAlertView(title: title, message: message, delegate: nil, cancelButtonTitle: "OK").show()
        }
        
        (self --> "mode")
            .deliverOn(RACScheduler.mainThreadScheduler())
            .subscribeNext { _ in self.updateStrings() }
        
        (self --> "mode")
            .skip(1)
            .deliverOn(RACScheduler.mainThreadScheduler())
            .subscribeNext { _ in self.updatePhoneRow() }
    }
    
    func toggleMode() {
        self.mode = self.mode == "signIn" ? "signUp" : "signIn"
    }
    
    func updateStrings() {
        let strings = stringsForMode(mode)
        
        self.footerButton.setTitle(strings["button"], forState: .Normal)
        self.footerButton.setTitle(strings["button"], forState: .Disabled)
        self.footerSwitchButton.setTitle(strings["switch"], forState: .Normal)
    }
    
    func updatePhoneRow() {
        let phone = NSIndexPath(forRow: 1, inSection: 0)
        
        self.emailTextField.becomeFirstResponder()
        
        self.tableView.beginUpdates()
        
        if self.mode == "signIn" {
            self.tableView.deleteRowsAtIndexPaths([phone], withRowAnimation: .Top)
        } else {
            self.tableView.insertRowsAtIndexPaths([phone], withRowAnimation: .Top)
        }
        
        self.tableView.endUpdates()
    }
    
    func layoutSubviews() {
        let views = [
            "label": headerLabel,
            "button": footerButton,
            "switch_button": footerSwitchButton
        ]
        
        hw.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-(hmargin)-[label(>=150)]-(hmargin)-|", options: nil, metrics: metrics, views: views))
        hw.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(fvmargin)-[label]-(fvmargin)-|", options: nil, metrics: metrics, views: views))
        
        fw.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-(hmargin)-[button(>=150)]-(hmargin)-|", options: nil, metrics: metrics, views: views))
        fw.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-(hmargin)-[switch_button(>=150)]-(hmargin)-|", options: nil, metrics: metrics, views: views))
        fw.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(fvmargin)-[button]-(fvmargin)-[switch_button]-(vmargin)-|", options: nil, metrics: metrics, views: views))
    }
    
    func isValidEmail(email: NSString) -> NSNumber {
        return email.length > 3 && email.containsString("@")
    }
    
    func isValidPhone(phone: NSString) -> NSNumber {
        return phone.length > 5
    }
    
    func isValidPassword(password: NSString) -> NSNumber {
        return password.length > 3
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        emailTextField.becomeFirstResponder()
    }
    
    func textFieldShouldReturn(textField: UITextField!) -> Bool  {
        switch textField {
        case emailTextField:
            (mode == "signIn" ? passwordTextField : phoneTextField).becomeFirstResponder()
        case phoneTextField:
            passwordTextField.becomeFirstResponder()
        default:
            footerButton.sendActionsForControlEvents(.TouchUpInside)
        }
        
        return false
    }

    // #pragma mark - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return mode == "signIn" ? 2 : 3
    }

    override func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell? {
        let cellID = "signInCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(cellID) as? UITableViewCell

        if !cell {
            let newCell = UITableViewCell(style: .Default, reuseIdentifier: cellID)
            newCell.selectionStyle = .None
            newCell.backgroundColor = UIColor.clearColor()
            
            cell = newCell
        }
        
        configureCell(cell!, atIndexPath: indexPath)

        return cell
    }
    
    func getField(index: Int) -> UIView {
        let signInFields = [emailTextField, passwordTextField]
        let signUpFields = [emailTextField, phoneTextField, passwordTextField]
        let fields = mode == "signIn" ? signInFields : signUpFields
        
        return fields[index]
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let field = getField(indexPath.item)
        let content = cell.contentView
        
        content.addSubview(field)
        
        let views = [ "field": field ]
        
        content.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-(hmargin)-[field(>=150)]-(hmargin)-|", options: nil, metrics: metrics, views: views))
        content.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-(vmargin)-[field]-(vmargin)-|", options: nil, metrics: metrics, views: views))
    }
    
    override func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat  {
        let h = emailTextField.frame.height
        
        if h == 0 {
            // not laid out, opt for default behavior
            return super.tableView(tableView, heightForRowAtIndexPath: indexPath)
        }
        
        return 2 * 10 + emailTextField.frame.height
    }

}