//
//  ChatViewController.swift
//  Rocket.Chat
//
//  Created by Rafael K. Streit on 7/21/16.
//  Copyright © 2016 Rocket.Chat. All rights reserved.
//

import SideMenu
import RealmSwift
import SlackTextViewController
import SafariServices
import MobilePlayer

class ChatViewController: SLKTextViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    weak var chatTitleView: ChatTitleView?
    
    var messagesToken: NotificationToken!
    var messages: Results<Message>!
    var subscription: Subscription! {
        didSet {
            updateSubscriptionInfo()
            markAsRead()
        }
    }
    
    
    // MARK: View Life Cycle
    
    class func sharedInstance() -> ChatViewController? {
        if let nav = UIApplication.shared.delegate?.window??.rootViewController as? UINavigationController {
            return nav.viewControllers.first as? ChatViewController
        }
        
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.tintColor = UIColor(rgb: 0x5B5B5B, alphaVal: 1)

        isInverted = false
        
        setupTitleView()
        setupSideMenu()
        registerCells()
    }
    
    fileprivate func setupTitleView() {
        // FIXME: Use typealias or associatedType in the protocol, to avoid casting
        let view = ChatTitleView.instanceFromNib() as? ChatTitleView
        self.navigationItem.titleView = view
        chatTitleView = view
    }
    
    override class func collectionViewLayout(for decoder: NSCoder) -> UICollectionViewLayout {
        return UICollectionViewFlowLayout()
    }
    
    fileprivate func registerCells() {
        self.collectionView?.register(UINib(
            nibName: "ChatMessageCell",
            bundle: Bundle.main
        ), forCellWithReuseIdentifier: ChatMessageCell.identifier)
    }
    
    fileprivate func scrollToBottom(_ animated: Bool = false) {
        let totalItems = collectionView!.numberOfItems(inSection: 0) - 1
        
        if totalItems > 0 {
            let indexPath = IndexPath(row: totalItems, section: 0)
            collectionView?.scrollToItem(at: indexPath, at: .bottom, animated: animated)
        }
    }
    
    
    // MARK: SlackTextViewController
    
    override func didPressRightButton(_ sender: Any?) {
        sendMessage()
    }
    
    override func didPressReturnKey(_ keyCommand: UIKeyCommand?) {
        sendMessage()
    }
    
    override func textViewDidBeginEditing(_ textView: UITextView) {
        scrollToBottom()
    }
    
    
    // MARK: Message
    
    fileprivate func sendMessage() {
        guard let message = textView.text else { return }
        
        SubscriptionManager.sendTextMessage(message, subscription: subscription) { [unowned self] (response) in
            self.textView.text = ""
        }
    }
    
    
    // MARK: Subscription
    
    fileprivate func markAsRead() {
        SubscriptionManager.markAsRead(subscription) { (response) in
            // Nothing, for now
        }
    }
    
    fileprivate func updateSubscriptionInfo() {
        if let token = messagesToken {
            token.stop()
        }

        activityIndicator.startAnimating()
        title = subscription?.name
        chatTitleView?.subscription = subscription
        messages = subscription?.messages.sorted(byProperty: "createdAt", ascending: true)
        messagesToken = messages.addNotificationBlock { [unowned self] (changes) in
            if self.messages.count > 0 {
                self.activityIndicator.stopAnimating()
            }

            self.collectionView?.reloadData()
            self.collectionView?.layoutIfNeeded()
            self.scrollToBottom()
        }
        
        MessageManager.getHistory(subscription) { [unowned self] (response) in
            self.activityIndicator.stopAnimating()
            self.messages = self.subscription?.fetchMessages()
            self.collectionView?.reloadData()
            self.collectionView?.layoutIfNeeded()
            self.scrollToBottom()
        }
        
        MessageManager.changes(subscription)
    }
    
    
    // MARK: IBAction
    
    @IBAction func buttonMenuDidPressed(_ sender: AnyObject) {
        present(SideMenuManager.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    
    // MARK: Side Menu
    
    fileprivate func setupSideMenu() {
        let storyboardSubscriptions = UIStoryboard(name: "Subscriptions", bundle: Bundle.main)
        SideMenuManager.menuFadeStatusBar = false
        SideMenuManager.menuLeftNavigationController = storyboardSubscriptions.instantiateInitialViewController() as? UISideMenuNavigationController
        
        SideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
        SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view)
    }
    
}


// MARK: UICollectionViewDataSource

extension ChatViewController {
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let message = messages![indexPath.row]

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ChatMessageCell.identifier,
            for: indexPath
        ) as! ChatMessageCell

        cell.delegate = self
        cell.message = message
        return cell
    }
    
}


extension ChatViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let message = messages![indexPath.row]
        let fullWidth = UIScreen.main.bounds.size.width
        let height = ChatMessageCell.cellMediaHeightFor(message: message)
        return CGSize(width: fullWidth, height: height)
    }
    
}


// MARK: ChatURLCellProtocol

extension ChatViewController: ChatMessageCellProtocol {
    
    func openURL(url: URL) {
        let controller = SFSafariViewController(url: url)
        present(controller, animated: true, completion: nil)
    }
    
    func openURLFromCell(url: MessageURL) {
        guard let targetURL = url.targetURL else { return }
        guard let destinyURL = URL(string: targetURL) else { return }
        let controller = SFSafariViewController(url: destinyURL)
        present(controller, animated: true, completion: nil)
    }
    
    func openVideoFromCell(attachment: Attachment) {
        guard let videoURL = attachment.fullVideoURL() else { return }
        let controller = MobilePlayerViewController(contentURL: videoURL)
        controller.title = attachment.title
        controller.activityItems = [attachment.title, videoURL]
        present(controller, animated: true, completion: nil)
    }

}
