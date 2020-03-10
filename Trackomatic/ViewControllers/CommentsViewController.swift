//
//  CommentsViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 09/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class CommentsViewController: NSViewController
{
    @objc dynamic var commentManager: CommentManager? {
        didSet
        {
            if let old = oldValue
            {
                old.removeObserver( self, forKeyPath: "comments" );
            }
            if let new = commentManager
            {
                new.addObserver( self, forKeyPath: "comments", options: [], context: nil );
            }
            update();
        }
    };
    
    @objc dynamic var anchor: String? {
        didSet
        {
            update();
        }
    };
    
    @IBOutlet weak var stackView: CommentsStackView!
    private var commentViewControllers : [ CommentViewController ] = [];
    
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "comments"
        {
            update();
        }
    }
    
    override func viewDidLoad()
    {
        update();
    }
    
    private func update()
    {
        if !isViewLoaded { return; }
        
        // Very naiive implementation for now
        
        for vc in commentViewControllers
        {
            stackView.removeView( vc.view );
        }
        
        commentViewControllers.removeAll();
        
        guard let manager = commentManager else { return; }
        
        guard let sb = storyboard else { return; }
        
        for comment in manager.commentsFor( anchor: anchor ?? "" )
        {
            let vc = sb.instantiateController( withIdentifier: "commentViewController" ) as! CommentViewController;
            vc.manager = commentManager;
            vc.comment = comment;
            commentViewControllers.append( vc );
            stackView.addArrangedSubview( vc.view );
        }
    }
}

class CommentsStackView : NSStackView
{
    override var isFlipped: Bool { return true; }
}
