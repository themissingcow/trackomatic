//
//  Copyright (c) 2020, Tom Cowland. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//      * Redistributions of source code must retain the above
//        copyright notice, this list of conditions and the following
//        disclaimer.
//
//      * Redistributions in binary form must reproduce the above
//        copyright notice, this list of conditions and the following
//        disclaimer in the documentation and/or other materials provided with
//        the distribution.
//
//      * Neither the name of Tom Cowland nor the names of
//        any other contributors to this software may be used to endorse or
//        promote products derived from this software without specific prior
//        written permission.
//
//      * Any redistribution of the source code, it's binary form, or any
//        project derived from the source code must remain free of charge and
//        on a not for profit basis.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
//  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Cocoa

class CommentViewController: NSViewController, NSTextViewDelegate
{
    @IBInspectable var color: NSColor = NSColor( white: 0.0, alpha: 0.05 );
	@IBInspectable var highlighedColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.2);
    
    enum Mode {
        case new;
        case existing;
    }
    
    var mode: Mode = .existing {
        willSet { willChangeValue( forKey: "deletable" ); }
        didSet { didChangeValue( forKey: "deletable" ); }
    }
    
    @objc dynamic var comment: Comment? {
        didSet {
            textView?.drawsBackground = editable;
            updateHeight();
        }
    };
    
    @objc dynamic var editable: Bool = false {
        willSet { willChangeValue( forKey: "deletable" ); }
        didSet { didChangeValue( forKey: "deletable" ); }
    }
    
    @objc dynamic var deletable: Bool {
        return editable && mode != .new;
    }
    
    @objc dynamic var commentHighted: Bool = false {
        didSet {
            if let c = comment
            {
                box.fillColor = c.highlighted ? highlighedColor : color;
            }
        }
    }
    
    var textView: NSTextView?
    var textViewHeightContstraint: NSLayoutConstraint?;
    
    @IBOutlet weak var box: NSBox!
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
        
        // For some reason KVO on "highlighted" causes crashes in assignment
        bind( NSBindingName("commentHighted"), to: self, withKeyPath: "comment.highlighted", options: [:] );
        
        updateHeight();
    }
    
    override func viewDidLayout()
    {
        super.viewDidLayout();
        updateHeight();
    }
    
    @IBAction func delete( _ sender: Any )
    {
        guard let c = comment else { return };
        comment = nil;
        c.delete();
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
