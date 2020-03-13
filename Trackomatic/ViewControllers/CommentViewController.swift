//
//  CommentViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 10/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class CommentViewController: NSViewController, NSTextViewDelegate
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
            textView?.drawsBackground = editable;
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
    
    var textView: NSTextView?
    var textViewHeightContstraint: NSLayoutConstraint?;
    
    @IBOutlet weak var boxView: NSView!;
    @IBOutlet weak var topAnchorItem: NSTextField!
    
    override func viewDidLoad() {
        
        // Interface Builder insists on embedding NSTextViews in an NSCrollView, which we really
        // don't wan't as it interferes with scrolling the whole comments list. If we make our own
        // we can avoid that.
            
        let t = NSTextView();
        t.delegate = self;
        
        t.translatesAutoresizingMaskIntoConstraints = false;
        t.isVerticallyResizable = true;
        t.isHorizontallyResizable = false;
        t.textContainer?.widthTracksTextView = true;
        t.isRichText = false;
        t.drawsBackground = editable;
        
        boxView.addSubview( t );

        t.leadingAnchor.constraint( equalTo: t.superview!.leadingAnchor, constant: 8 ).isActive = true;
        t.superview!.trailingAnchor.constraint( equalTo: t.trailingAnchor, constant: 8 ).isActive = true;
        t.superview!.bottomAnchor.constraint( equalTo: t.bottomAnchor, constant: 8 ).isActive = true;
        t.topAnchor.constraint( equalTo: topAnchorItem.bottomAnchor, constant: 8 ).isActive = true;
        
        textView = t;
        textViewHeightContstraint = t.heightAnchor.constraint( greaterThanOrEqualToConstant: 20 );
        textViewHeightContstraint?.isActive = true;

        t.bind( .editable, to: self, withKeyPath: "editable" );
        t.bind( .value, to: self, withKeyPath: "comment.comment", options: [ NSBindingOption.continuouslyUpdatesValue : true ] );
        
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
        
        guard let lm = textView?.layoutManager else { return; }
        
        lm.ensureLayout( for: textView!.textContainer! );
        let h: CGFloat = max( 20, lm.usedRect( for: textView!.textContainer! ).height );
        textViewHeightContstraint?.constant = h;
    }
    
    func textDidChange(_ notification: Notification)
    {
        updateHeight();
    }
}
