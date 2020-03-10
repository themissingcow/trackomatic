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
    var commentViewController: CommentViewController?;
    @IBOutlet weak var placeholderView: NSView!

    var comment: Comment? {
        didSet
        {
            commentViewController?.comment = comment;
        }
    }
    var commentManager: CommentManager? {
        didSet
        {
            commentViewController?.manager = commentManager;
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad();
        
        let vc = storyboard!.instantiateController( withIdentifier: "commentViewController" ) as! CommentViewController;
       
        addChild( vc );
        view.addSubview( vc.view );
        vc.view.frame = placeholderView.frame;
        vc.mode = .new;
        vc.comment = comment;
        vc.manager = commentManager;

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
