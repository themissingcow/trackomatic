//
//  CommentViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 10/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class CommentViewController: NSViewController, NSTextDelegate
{
    enum Mode {
        case new;
        case existing;
    }
    
    var mode: Mode = .existing;
    
    @objc dynamic var comment: Comment? {
        willSet { willChangeValue(forKey: "editable"); willChangeValue( forKey: "deletable" ); }
        didSet {
            didChangeValue( forKey: "editable");
            didChangeValue( forKey: "deletable" );
            updateHeight();
        }
    };
    
    @objc dynamic var manager: CommentManager? {
           willSet { willChangeValue(forKey: "editable"); willChangeValue( forKey: "deletable" ); }
           didSet { didChangeValue( forKey: "editable"); didChangeValue( forKey: "deletable" ); }
    };
    
    @objc dynamic var editable: Bool {
        return comment != nil && ( comment?.shortName == manager?.userShortName );
    }
    
    @objc dynamic var deletable: Bool {
        return editable && mode != .new;
    }
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var textViewHeightContstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        updateHeight();
    }
    
    @IBAction func delete( _ sender: Any )
    {
        guard let c = comment else { return };
        comment = nil;
        manager?.remove(comments: [ c ] );
    }
    
    private func updateHeight()
    {
        if !isViewLoaded { return; }
        
        guard let lm = textView.layoutManager else { return; }
        
        lm.ensureLayout( for: textView.textContainer! );
        let h: CGFloat = max( 40, lm.usedRect( for: textView.textContainer! ).height );
        textViewHeightContstraint.constant = h;
    }
    
    func textDidChange(_ notification: Notification)
    {
        updateHeight();
    }
}
