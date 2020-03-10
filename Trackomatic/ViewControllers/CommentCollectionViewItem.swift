//
//  CommentCollectionViewItem.swift
//  Trackomatic
//
//  Created by Tom Cowland on 09/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class CommentCollectionViewItem: NSCollectionViewItem
{
    @objc dynamic var comment: Comment?;
    
    @IBOutlet weak var displayNameLabel: NSTextField!
    @IBOutlet var commentTextView: NSTextView!
    
    override func viewDidLoad()
    {
        // Manual bindings make programatic instantiation easier as we can use this as
        // both a CollectionViewItem and a standard ViewController.
        displayNameLabel.bind( .value, to: self, withKeyPath: "comment.displayName", options: [:] );
        commentTextView.bind( .value, to: self, withKeyPath: "comment.comment", options: [ .continuouslyUpdatesValue : true ] );
    }

}
