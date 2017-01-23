import Foundation
import UIKit
import Aztec
import Gridicons
import WordPressShared

class AztecPostViewController: UIViewController {

    var onClose: ((_ changesSaved: Bool) -> ())?

    fileprivate(set) lazy var richTextView: Aztec.TextView = {
        let tv = Aztec.TextView(defaultFont: Constants.defaultFont, defaultMissingImage: Constants.defaultMissingImage)

        tv.font = Constants.defaultFont
        tv.accessibilityLabel = NSLocalizedString("Rich Content", comment: "Post Rich content")
        tv.delegate = self
        let toolbar = self.createToolbar()
        toolbar.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 44.0)
        toolbar.formatter = self
        tv.inputAccessoryView = toolbar
        tv.textColor = UIColor.darkText
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.keyboardDismissMode = .interactive

        return tv
    }()

    fileprivate(set) lazy var htmlTextView: UITextView = {
        let tv = UITextView()

        tv.accessibilityLabel = NSLocalizedString("HTML Content", comment: "Post HTML content")
        tv.font = WPFontManager.merriweatherRegularFont(ofSize: 16)
        tv.textColor = UIColor.darkText
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isHidden = true
        tv.keyboardDismissMode = .interactive

        return tv
    }()

    fileprivate(set) lazy var titleTextField: UITextField = {
        let placeholderText = NSLocalizedString("Enter title here", comment: "Label for the title of the post field. Should be the same as WP core.")
        let tf = UITextField()

        tf.accessibilityLabel = NSLocalizedString("Title", comment: "Post title")
        tf.attributedPlaceholder = NSAttributedString(string: placeholderText,
                                                      attributes: [NSForegroundColorAttributeName: WPStyleGuide.greyLighten30()])
        tf.delegate = self
        tf.font = WPFontManager.merriweatherBoldFont(ofSize: 24.0)
        let toolbar = self.createToolbar()
        toolbar.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 44.0)
        toolbar.enabled = false
        tf.inputAccessoryView = toolbar
        tf.returnKeyType = .next
        tf.textColor = UIColor.darkText
        tf.translatesAutoresizingMaskIntoConstraints = false

        return tf
    }()

    fileprivate(set) lazy var separatorView: UIView = {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 1))

        v.backgroundColor = WPStyleGuide.greyLighten30()
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    fileprivate lazy var separatorButtonItem: UIBarButtonItem = {
        let separator = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        separator.width = Constants.separatorButtonWidth
        return separator
    }()

    fileprivate lazy var closeBarButtonItem: UIBarButtonItem = {
        let image = Gridicon.iconOfType(.cross)
        let cancelButton = WPStyleGuide.buttonForBar(with: image, target: self, selector: #selector(cancelEditingAction))
        cancelButton.leftSpacing = Constants.cancelButtonPadding.left
        cancelButton.rightSpacing = Constants.cancelButtonPadding.right

        let cancelItem = UIBarButtonItem(customView: cancelButton)
        cancelItem.accessibilityLabel = NSLocalizedString("Cancel", comment: "Action button to close edior and cancel changes or insertion of post")
        return cancelItem
    }()

    fileprivate lazy var moreBarButtonItem: UIBarButtonItem = {
        let image = Gridicon.iconOfType(.ellipsis)
        let moreItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(displayMoreSheet))
        moreItem.accessibilityLabel = NSLocalizedString("More", comment: "Action button to display more available options")
        return moreItem
    }()

    fileprivate lazy var blogPickerButton: WPBlogSelectorButton = {
        let button = WPBlogSelectorButton(frame: .zero, buttonStyle: .typeSingleLine)
        button.addTarget(self, action: #selector(displayBlogSelector), for: .touchUpInside)
        return button
    }()

    fileprivate(set) var mode = EditionMode.richText {
        didSet {
            switch mode {
            case .html:
                switchToHTML()
            case .richText:
                switchToRichText()
            }
        }
    }

    fileprivate(set) var post: AbstractPost

    // MARK: - Lifecycle Methods

    init(post: AbstractPost) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        preconditionFailure("Aztec Post View Controller must be initialized by code")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        WPFontManager.loadMerriweatherFontFamily()

        configureNavigationBar()
        configureView()
        configureSubviews()

        createRevisionOfPost()
        titleTextField.text = post.postTitle

        if let content = post.content {
            richTextView.setHTML(content)
        }

        view.setNeedsUpdateConstraints()
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        startListeningToNotifications()
        refreshNavigationBarButtons()
    }


    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopListeningToNotifications()
    }


    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // TODO: Update toolbars
        //    [self.editorToolbar configureForHorizontalSizeClass:newCollection.horizontalSizeClass];
        //    [self.titleToolbar configureForHorizontalSizeClass:newCollection.horizontalSizeClass];

    }


    // MARK: - Configuration Methods

    override func updateViewConstraints() {

        super.updateViewConstraints()

        let defaultMargin = Constants.defaultMargin

        NSLayoutConstraint.activate([
            titleTextField.leftAnchor.constraint(equalTo: view.leftAnchor, constant: defaultMargin),
            titleTextField.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -defaultMargin),
            titleTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: defaultMargin),
            titleTextField.heightAnchor.constraint(equalToConstant: titleTextField.font!.lineHeight)
            ])

        NSLayoutConstraint.activate([
            separatorView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: defaultMargin),
            separatorView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -defaultMargin),
            separatorView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: defaultMargin),
            separatorView.heightAnchor.constraint(equalToConstant: separatorView.frame.height)
            ])

        NSLayoutConstraint.activate([
            richTextView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: defaultMargin),
            richTextView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -defaultMargin),
            richTextView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: defaultMargin),
            richTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -defaultMargin)
            ])

        NSLayoutConstraint.activate([
            htmlTextView.leftAnchor.constraint(equalTo: richTextView.leftAnchor),
            htmlTextView.rightAnchor.constraint(equalTo: richTextView.rightAnchor),
            htmlTextView.topAnchor.constraint(equalTo: richTextView.topAnchor),
            htmlTextView.bottomAnchor.constraint(equalTo: richTextView.bottomAnchor),
            ])
    }

    func configureNavigationBar() {
        title = NSLocalizedString("Aztec", comment: "Aztec Editor's Title")

        navigationController?.navigationBar.isTranslucent = false
    }

    func configureView() {
        edgesForExtendedLayout = UIRectEdge()
        view.backgroundColor = .white
    }

    func configureSubviews() {
        view.addSubview(titleTextField)
        view.addSubview(separatorView)
        view.addSubview(richTextView)
        view.addSubview(htmlTextView)
    }

    func startListeningToNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: .UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: .UIKeyboardWillHide, object: nil)
    }

    func stopListeningToNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        notificationCenter.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
    }

    func refreshNavigationBarButtons() {
        // Refresh the Picker's Title
        let blogName = post.blog.settings?.name ?? post.blog.url ?? String()
        let titleText = NSMutableAttributedString(string: blogName, attributes: Constants.titleAttributes)

        blogPickerButton.buttonMode = isSingleSiteMode ? .singleSite : .multipleSite
        blogPickerButton.setAttributedTitle(titleText, for: .normal)
        blogPickerButton.sizeToFit()

        // Update the Blog Picker's width to the appropriate size for the horizontal size class
        let pickerButtonMaxWidth = hasHorizontallyCompactView() ? Constants.titleButtonRegularWidth : Constants.titleButtonRegularWidth
        var pickerButtonFrame = blogPickerButton.frame
        pickerButtonFrame.size.width = min(pickerButtonFrame.width, pickerButtonMaxWidth)
        pickerButtonFrame.size.height = Constants.titleButtonRegularHeight
        blogPickerButton.frame = pickerButtonFrame

        // Refresh Button Items
        let pickerBarButtonItem = UIBarButtonItem(customView: blogPickerButton)
        navigationItem.leftBarButtonItems = [separatorButtonItem, closeBarButtonItem, pickerBarButtonItem]
        navigationItem.rightBarButtonItem = moreBarButtonItem
    }


    // MARK: - Keyboard Handling

    func keyboardWillShow(_ notification: Foundation.Notification) {
        guard
            let userInfo = notification.userInfo as? [String: AnyObject],
            let keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else {
                return
        }

        refreshInsets(forKeyboardFrame: keyboardFrame)
    }

    func keyboardWillHide(_ notification: Foundation.Notification) {
        guard
            let userInfo = notification.userInfo as? [String: AnyObject],
            let keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else {
                return
        }

        refreshInsets(forKeyboardFrame: keyboardFrame)
    }

    fileprivate func refreshInsets(forKeyboardFrame keyboardFrame: CGRect) {
        htmlTextView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: view.frame.maxY - keyboardFrame.minY, right: 0)
        htmlTextView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: view.frame.maxY - keyboardFrame.minY, right: 0)

        richTextView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: view.frame.maxY - keyboardFrame.minY, right: 0)
        richTextView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: view.frame.maxY - keyboardFrame.minY, right: 0)
    }


    func updateFormatBar() {
        guard let toolbar = richTextView.inputAccessoryView as? Aztec.FormatBar else {
            return
        }

        let identifiers = richTextView.formatIdentifiersForTypingAttributes()
        toolbar.selectItemsMatchingIdentifiers(identifiers)
    }
}


// MARK: - Actions
extension AztecPostViewController {
    @IBAction func cancelEditingAction() {
        cancelEditing()
    }

    @IBAction func displayBlogSelector() {
        let successHandler: BlogSelectorSuccessHandler = { selectedObjectID in
            guard let blog = self.mainContext.object(with: selectedObjectID) as? Blog else {
                return
            }

            self.createRevisionOfPost(in: blog)
        }

        let dismissHandler: BlogSelectorDismissHandler = {
            self.dismiss(animated: true, completion: nil)
        }

        let selectorViewController = BlogSelectorViewController(selectedBlogObjectID: post.blog.objectID,
                                                                successHandler: successHandler,
                                                                dismissHandler: dismissHandler)
        selectorViewController.title = NSLocalizedString("Select Site", comment: "Blog Picker's Title")
        selectorViewController.displaysPrimaryBlogOnTop = true

        let navigationController = UINavigationController(rootViewController: selectorViewController)
        navigationController.modalPresentationStyle = .popover

        let popoverController = navigationController.popoverPresentationController
        popoverController?.permittedArrowDirections = .up
        popoverController?.sourceView = blogPickerButton

        present(navigationController, animated: true, completion: nil)
    }

    @IBAction func displayMoreSheet() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        switch mode {
        case .richText:
            alertController.addAction(switchHTMLAlertAction())
        case .html:
            alertController.addAction(switchRichAlertAction())
        }

        alertController.addAction(optionsAlertAction())
        alertController.addCancelActionWithTitle(NSLocalizedString("Cancel", comment: "Dismisses the Alert from Screen"))
        alertController.popoverPresentationController?.barButtonItem = moreBarButtonItem

        view.endEditing(true)
        present(alertController, animated: true, completion: nil)
    }

    private func displayPostOptions() {
        let settingsViewController = PostSettingsViewController(post: post)
        settingsViewController.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(settingsViewController, animated: true)
    }

    private func switchHTMLAlertAction() -> UIAlertAction {
        let title = NSLocalizedString("Switch to HTML", comment: "Switches the Editor to HTML Mode")
        return UIAlertAction(title: title, style: .default, handler: { _ in
            self.mode = .html
        })
    }

    private func switchRichAlertAction() -> UIAlertAction {
        let title = NSLocalizedString("Switch to Rich Text", comment: "Switches the Editor to Rich Text Mode")
        return UIAlertAction(title: title, style: .default, handler: { _ in
            self.mode = .richText
        })
    }

    private func optionsAlertAction() -> UIAlertAction {
        let title = NSLocalizedString("Options", comment: "Displays the Post's Options")
        return UIAlertAction(title: title, style: .default, handler: { _ in
            self.displayPostOptions()
        })
    }
}


// MARK: - UITextViewDelegate methods
extension AztecPostViewController : UITextViewDelegate {
    func textViewDidChangeSelection(_ textView: UITextView) {
        updateFormatBar()
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let richTextView = textView as? Aztec.TextView else {
            return
        }

        // TODO: This may not be super performant; Instrument and improve if needed and remove this TODO
        post.content = richTextView.getHTML()

        ContextManager.sharedInstance().save(post.managedObjectContext)
    }
}


// MARK: - UITextFieldDelegate methods
extension AztecPostViewController : UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        post.postTitle = textField.text

        ContextManager.sharedInstance().save(post.managedObjectContext)
    }
}


// MARK: - HTML Mode Switch methods
extension AztecPostViewController {
    enum EditionMode {
        case richText
        case html
    }

    fileprivate func switchToHTML() {
        view.endEditing(true)

        htmlTextView.text = richTextView.getHTML()
        htmlTextView.isHidden = false
        richTextView.isHidden = true
    }

    fileprivate func switchToRichText() {
        view.endEditing(true)

        richTextView.setHTML(htmlTextView.text)
        richTextView.isHidden = false
        htmlTextView.isHidden = true
    }
}

// MARK: - FormatBarDelegate Conformance
extension AztecPostViewController : Aztec.FormatBarDelegate {

    func handleActionForIdentifier(_ identifier: FormattingIdentifier) {

        switch identifier {
            case .bold:
                toggleBold()
            case .italic:
                toggleItalic()
            case .underline:
                toggleUnderline()
            case .strikethrough:
                toggleStrikethrough()
            case .blockquote:
                toggleBlockquote()
            case .unorderedlist:
                toggleUnorderedList()
            case .orderedlist:
                toggleOrderedList()
            case .link:
                toggleLink()
            case .media:
                showImagePicker()
        }
        updateFormatBar()
    }

    func toggleBold() {
        richTextView.toggleBold(range: richTextView.selectedRange)
    }


    func toggleItalic() {
        richTextView.toggleItalic(range: richTextView.selectedRange)
    }


    func toggleUnderline() {
        richTextView.toggleUnderline(range: richTextView.selectedRange)
    }


    func toggleStrikethrough() {
        richTextView.toggleStrikethrough(range: richTextView.selectedRange)
    }


    func toggleOrderedList() {
        richTextView.toggleOrderedList(range: richTextView.selectedRange)
    }


    func toggleUnorderedList() {
        richTextView.toggleUnorderedList(range: richTextView.selectedRange)
    }


    func toggleBlockquote() {
        richTextView.toggleBlockquote(range: richTextView.selectedRange)
    }


    func toggleLink() {
        var linkTitle = ""
        var linkURL: URL? = nil
        var linkRange = richTextView.selectedRange
        // Let's check if the current range already has a link assigned to it.
        if let expandedRange = richTextView.linkFullRange(forRange: richTextView.selectedRange) {
            linkRange = expandedRange
            linkURL = richTextView.linkURL(forRange: expandedRange)
        }

        linkTitle = richTextView.attributedText.attributedSubstring(from: linkRange).string
        showLinkDialog(forURL: linkURL, title: linkTitle, range: linkRange)
    }


    func showLinkDialog(forURL url: URL?, title: String?, range: NSRange) {

        let isInsertingNewLink = (url == nil)
        // TODO: grab link from pasteboard if available

        let insertButtonTitle = isInsertingNewLink ? NSLocalizedString("Insert Link", comment: "Label action for inserting a link on the editor") : NSLocalizedString("Update Link", comment: "Label action for updating a link on the editor")
        let removeButtonTitle = NSLocalizedString("Remove Link", comment: "Label action for removing a link from the editor")
        let cancelButtonTitle = NSLocalizedString("Cancel", comment: "Cancel button")

        let alertController = UIAlertController(title: insertButtonTitle,
                                                message: nil,
                                                preferredStyle: UIAlertControllerStyle.alert)

        alertController.addTextField(configurationHandler: { [weak self]textField in
            textField.clearButtonMode = UITextFieldViewMode.always
            textField.placeholder = NSLocalizedString("URL", comment: "URL text field placeholder")

            textField.text = url?.absoluteString

            textField.addTarget(self,
                action: #selector(AztecPostViewController.alertTextFieldDidChange),
                for: UIControlEvents.editingChanged)
            })

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextFieldViewMode.always
            textField.placeholder = NSLocalizedString("Link Name", comment: "Link name field placeholder")
            textField.isSecureTextEntry = false
            textField.autocapitalizationType = UITextAutocapitalizationType.sentences
            textField.autocorrectionType = UITextAutocorrectionType.default
            textField.spellCheckingType = UITextSpellCheckingType.default

            textField.text = title
        })

        let insertAction = UIAlertAction(title: insertButtonTitle,
                                         style: UIAlertActionStyle.default,
                                         handler: { [weak self] action in

                                            self?.richTextView.becomeFirstResponder()
                                            let linkURLString = alertController.textFields?.first?.text
                                            var linkTitle = alertController.textFields?.last?.text

                                            if  linkTitle == nil  || linkTitle!.isEmpty {
                                                linkTitle = linkURLString
                                            }

                                            guard
                                                let urlString = linkURLString,
                                                let url = URL(string: urlString),
                                                let title = linkTitle
                                                else {
                                                    return
                                            }
                                            self?.richTextView.setLink(url, title: title, inRange: range)
            })

        let removeAction = UIAlertAction(title: removeButtonTitle,
                                         style: UIAlertActionStyle.destructive,
                                         handler: { [weak self] action in
                                            self?.richTextView.becomeFirstResponder()
                                            self?.richTextView.removeLink(inRange: range)
            })

        let cancelAction = UIAlertAction(title: cancelButtonTitle,
                                         style: UIAlertActionStyle.cancel,
                                         handler: { [weak self]action in
                                            self?.richTextView.becomeFirstResponder()
            })

        alertController.addAction(insertAction)
        if !isInsertingNewLink {
            alertController.addAction(removeAction)
        }
        alertController.addAction(cancelAction)

        // Disabled until url is entered into field
        if let text = alertController.textFields?.first?.text {
            insertAction.isEnabled = !text.isEmpty
        }

        self.present(alertController, animated: true, completion: nil)
    }

    func alertTextFieldDidChange(_ textField: UITextField) {
        guard
            let alertController = presentedViewController as? UIAlertController,
            let urlFieldText = alertController.textFields?.first?.text,
            let insertAction = alertController.actions.first
            else {
                return
        }

        insertAction.isEnabled = !urlFieldText.isEmpty
    }


    func showImagePicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) ?? []
        picker.delegate = self
        picker.allowsEditing = false
        picker.navigationBar.isTranslucent = false
        picker.modalPresentationStyle = .currentContext

        present(picker, animated: true, completion: nil)
    }


    // MARK: -

    func createToolbar() -> Aztec.FormatBar {
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let items = [
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.addImage), identifier: .media),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.bold), identifier: .bold),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.italic), identifier: .italic),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.underline), identifier: .underline),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.strikethrough), identifier: .strikethrough),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.quote), identifier: .blockquote),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.listUnordered), identifier: .unorderedlist),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.listOrdered), identifier: .orderedlist),
            flex,
            Aztec.FormatBarItem(image: Gridicon.iconOfType(.link), identifier: .link),
            flex,
            ]

        let toolbar = Aztec.FormatBar()

        toolbar.barTintColor = UIColor(fromHex: 0xF9FBFC, alpha: 1)
        toolbar.tintColor = WPStyleGuide.greyLighten10()
        toolbar.highlightedTintColor = UIColor.blue
        toolbar.selectedTintColor = UIColor.darkGray
        toolbar.disabledTintColor = UIColor.lightGray
        toolbar.items = items
        return toolbar
    }

    func templateImage(named: String) -> UIImage {
        return UIImage(named: named)!.withRenderingMode(.alwaysTemplate)
    }
}


// MARK: - UINavigationControllerDelegate Conformance
extension AztecPostViewController: UINavigationControllerDelegate {

}


// MARK: - UIImagePickerControllerDelegate Conformance
extension AztecPostViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)

        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            return
        }

        // Insert Image + Reclaim Focus
        insertImage(image)
        richTextView.becomeFirstResponder()
    }
}

// MARK: - Cancel/Dismiss/Persistence Logic
extension AztecPostViewController {
    // TODO: Rip this out and put it into the PostService
    fileprivate func createRevisionOfPost() {
        guard let context = post.managedObjectContext else {
            return
        }

        // Using performBlock: with the AbstractPost on the main context:
        // Prevents a hang on opening this view on slow and fast devices
        // by deferring the cloning and UI update.
        // Slower devices have the effect of the content appearing after
        // a short delay

        context.performAndWait {
            self.post = self.post.createRevision()
            ContextManager.sharedInstance().save(context)
        }
    }

    fileprivate func createRevisionOfPost(in blog: Blog) {
// TODO: Implement Me
    }

    fileprivate func cancelEditing() {
        stopEditing()

        if post.canSave() && post.hasUnsavedChanges() {
            showPostHasChangesAlert()
        } else {
            discardChangesAndUpdateGUI()
        }
    }

    fileprivate func stopEditing() {
        if titleTextField.isFirstResponder {
            titleTextField.resignFirstResponder()
        }

        view.endEditing(true)
    }

    fileprivate func showPostHasChangesAlert() {
        let alertController = UIAlertController(
            title: NSLocalizedString("You have unsaved changes.", comment: "Title of message with options that shown when there are unsaved changes and the author is trying to move away from the post."),
            message: nil,
            preferredStyle: .actionSheet)

        // Button: Keep editing
        alertController.addCancelActionWithTitle(NSLocalizedString("Keep Editing", comment: "Button shown if there are unsaved changes and the author is trying to move away from the post."))

        // Button: Discard
        alertController.addDestructiveActionWithTitle(NSLocalizedString("Discard", comment: "Button shown if there are unsaved changes and the author is trying to move away from the post.")) { _ in
            self.discardChangesAndUpdateGUI()
        }

        // Button: Save Draft/Update Draft
        if post.hasLocalChanges() {
            if post.hasRemote() {
                // The post is a local draft or an autosaved draft: Discard or Save
                alertController.addDefaultActionWithTitle(NSLocalizedString("Save Draft", comment: "Button shown if there are unsaved changes and the author is trying to move away from the post.")) { _ in
                    // Save Draft
                }
            } else if post.status == PostStatusDraft {
                // The post was already a draft
                alertController.addDefaultActionWithTitle(NSLocalizedString("Update Draft", comment: "Button shown if there are unsaved changes and the author is trying to move away from an already published/saved post.")) { _ in
                    // Save Draft
                }
            }
        }

        alertController.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
        present(alertController, animated: true, completion: nil)
    }

    fileprivate func discardChanges() {
        guard let context = post.managedObjectContext, let originalPost = post.original else {
            return
        }

        post = originalPost
        post.deleteRevision()
        post.remove()

        ContextManager.sharedInstance().save(context)
    }

    fileprivate func discardChangesAndUpdateGUI() {
        discardChanges()

        onClose?(false)

        if isModal() {
            presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            _ = navigationController?.popViewController(animated: true)
        }
    }
}


// MARK: - Computed Properties
private extension AztecPostViewController {
    var mainContext: NSManagedObjectContext {
        return ContextManager.sharedInstance().mainContext
    }

    var currentBlogCount: Int {
        let service = BlogService(managedObjectContext: mainContext)
        return service?.blogCountForAllAccounts() ?? 0
    }

    var isSingleSiteMode: Bool {
        return currentBlogCount <= 1 || post.hasRemote()
    }
}


// MARK: - Media Support
private extension AztecPostViewController {
    func insertImage(_ image: UIImage) {
        //let index = richTextView.positionForCursor()
        //richTextView.insertImage(image, index: index)
        assertionFailure("Error: Aztec.TextView.swift no longer supports insertImage(image: UIImage, index: Int")
    }
}


// MARK: - Constants
fileprivate extension AztecPostViewController {
    struct Constants {
        static let defaultFont              = WPFontManager.merriweatherRegularFont(ofSize: 16)
        static let defaultMargin            = CGFloat(20)
        static let defaultMissingImage      = Gridicon.iconOfType(.image)
        static let separatorButtonWidth     = CGFloat(-12)
        static let cancelButtonPadding      = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 5)
        static let titleAttributes          = [NSFontAttributeName: WPFontManager.systemSemiBoldFont(ofSize: 16)]
        static let titleButtonCompactWidth  = CGFloat(125)
        static let titleButtonRegularWidth  = CGFloat(300)
        static let titleButtonRegularHeight = CGFloat(30)
    }
}
