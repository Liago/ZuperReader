import UIKit
import Social
import CoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let containerView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processShareRequest()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(white: 0, alpha: 0.5) // Dimmed background
        
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Saving to SuperReader..."
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .label
        statusLabel.textAlignment = .center
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 250),
            containerView.heightAnchor.constraint(equalToConstant: 150),
            
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -15),
            
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 15),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10)
        ])
    }
    
    // MARK: - Processing URL
    
    private func processShareRequest() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            finishWithError(message: "No content found.")
            return
        }

        let groupItem = DispatchGroup()
        var foundUrl: URL?

        for attachment in attachments {
            if attachment.canLoadObject(ofClass: NSURL.self) {
                groupItem.enter()
                _ = attachment.loadObject(ofClass: NSURL.self) { (item, error) in
                    if let url = item as? URL {
                        foundUrl = url
                    }
                    groupItem.leave()
                }
                break // Only process the first URL
            }
        }

        groupItem.notify(queue: .main) {
            if let url = foundUrl {
                self.saveArticle(url: url.absoluteString)
            } else {
                // Check if there is plain text containing a URL as fallback
                self.processTextFallback(attachments: attachments)
            }
        }
    }
    
    private func processTextFallback(attachments: [NSItemProvider]) {
        let groupItem = DispatchGroup()
        var foundText: String?
        
        for attachment in attachments {
            if attachment.canLoadObject(ofClass: NSString.self) {
                groupItem.enter()
                _ = attachment.loadObject(ofClass: NSString.self) { (item, error) in
                    if let text = item as? String {
                        foundText = text
                    }
                    groupItem.leave()
                }
                break
            }
        }
        
        groupItem.notify(queue: .main) {
            if let text = foundText, let urlString = self.extractURL(from: text) {
                self.saveArticle(url: urlString)
            } else {
                self.finishWithError(message: "No URL found to save.")
            }
        }
    }
    
    private func extractURL(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first?.url?.absoluteString
    }
    
    // MARK: - Saving
    
    private func saveArticle(url: String) {
        // Here we would typically use the Supabase SDK, but since we are in an extension
        // without access to the full app's Keychain context easily by default without AppGroups,
        // we can perform a direct API request or rely on a Shared App Group Database.
        
        // For SuperReader, we will use UserDefaults in a shared App Group to queue the URL
        // or attempt a direct backend call if we have an API endpoint.
        // Assuming we share UserDefaults:
        
        let appGroupIdentifier = "group.liagosoft.SuperReader"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            finishWithError(message: "App Group not configured correctly.")
            return
        }
        
        var pendingUrls = sharedDefaults.stringArray(forKey: "PendingSharedURLs") ?? []
        if !pendingUrls.contains(url) {
            pendingUrls.append(url)
            sharedDefaults.set(pendingUrls, forKey: "PendingSharedURLs")
        }
        
        // Let the user know it was saved to the queue
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            
            let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            checkmarkView.tintColor = .systemGreen
            checkmarkView.translatesAutoresizingMaskIntoConstraints = false
            self.containerView.addSubview(checkmarkView)
            
            NSLayoutConstraint.activate([
                checkmarkView.centerXAnchor.constraint(equalTo: self.containerView.centerXAnchor),
                checkmarkView.centerYAnchor.constraint(equalTo: self.containerView.centerYAnchor, constant: -15),
                checkmarkView.widthAnchor.constraint(equalToConstant: 40),
                checkmarkView.heightAnchor.constraint(equalToConstant: 40)
            ])
            
            self.statusLabel.text = "Saved! Open app to sync."
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }

    private func finishWithError(message: String) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            self.statusLabel.text = message
            self.statusLabel.textColor = .systemRed
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let error = NSError(domain: "com.liagosoft.SuperReader", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
                self.extensionContext?.cancelRequest(withError: error)
            }
        }
    }
}
