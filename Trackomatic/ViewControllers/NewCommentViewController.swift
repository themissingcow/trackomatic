//
//  NewCommentViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 09/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class NewCommentViewController: NSViewController
{
    var commentViewController: CommentCollectionViewItem?;
    @IBOutlet weak var placeholderView: NSView!

    var comment: Comment? {
        didSet
        {
            commentViewController?.comment = comment;
        }
    }
    var commentManager: CommentManager?;
    
    override func viewDidLoad()
    {
        super.viewDidLoad();
        
        let vc = CommentCollectionViewItem( nibName: "CommentCollectionViewItem", bundle: Bundle.main );
       
        addChild( vc );
        view.addSubview( vc.view );
        vc.view.frame = placeholderView.frame;
        vc.comment = comment;

        commentViewController = vc;
    }

    @IBAction func cancel( _ sender: Any )
    {
        dismiss( self );
    }
    
    @IBAction func addComment( _ sender: Any )
    {
        if let c = comment
        {
            commentManager?.add( comments: [ c ] );
        }
        dismiss( self );
    }
}
