//
//  CommentView.swift
//  Trackomatic
//
//  Created by Tom Cowland on 08/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

protocol TrackCommentsViewDelegate: class
{
    func trackCommentsView(
            _ view: TrackCommentsView,
            requestedCommentAt position: Double, ofLength length: Double?
    );
}

class TrackCommentsView: TimelineCommentView {
    
    @IBInspectable var anchor: String?;
    @IBOutlet var manager: CommentManager? {
        didSet {
            removeObservers( oldValue );
            addObservers( manager );
            updateDisplayComments();
        }
    };
    
    var delegate: TrackCommentsViewDelegate?;

    private func addObservers( _ manager: CommentManager? )
    {
        manager?.addObserver( self, forKeyPath: "comments", options: [], context: nil );
    }
    
    private func removeObservers( _ manager: CommentManager? )
    {
       manager?.removeObserver( self, forKeyPath: "comments" );
    }
    
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "comments"
        {
            updateDisplayComments();
        }
    }
    
    private func updateDisplayComments()
    {
        if let a = anchor
        {
            self.comments = manager?.commentsFor( anchor: a ) ?? [];
        }
        else
        {
            self.comments = []
        }
        self.setNeedsDisplay( bounds );
    }
    
    override func draw(_ dirtyRect: NSRect) {
                        
        super.draw( dirtyRect );

        let context = NSGraphicsContext.current!.cgContext;

        if length == 0
        {
            return;
        }
    
        if let downX = mouseDownX, let currentX = mouseX
        {
            let x = min( downX, currentX );
            let w = abs( downX - currentX );
            context.setFillColor( gray: 0.0, alpha: 0.1 );
            context.fill( CGRect( x: x, y: 0.0, width: w, height: bounds.height ) );
            
            context.setLineWidth( 1.0 );
            context.move( to: CGPoint( x: x, y: 0 ) );
            context.addLine(to: CGPoint( x: x, y: frame.height ));
            context.move( to: CGPoint( x: x + w, y: 0 ) );
            context.addLine(to: CGPoint( x: x + w, y: frame.height ));
            context.strokePath()
        }
    }
    
    private var mouseX: CGFloat?;
    private var mouseDownX: CGFloat?;
    
    override func mouseDragged(with event: NSEvent)
    {
        mouseX = convert( event.locationInWindow, from: nil ).x;
        setNeedsDisplay( bounds );
    }
    
    override func mouseDown( with event: NSEvent )
    {
        mouseDownX = convert( event.locationInWindow, from: nil ).x;
        mouseX = mouseDownX;
        setNeedsDisplay( bounds );
    }
    
    override func mouseUp( with event: NSEvent )
    {
        guard let downX = mouseDownX else { return; }
        
        let upX = convert( event.locationInWindow, from: nil ).x;
        
        let downPosition = Double( downX / bounds.width ) * length;
        let upPosition = Double( upX / bounds.width ) * length;
        
        let atMin = min( downPosition, upPosition );
        let atMax = max( downPosition, upPosition );
        
        mouseX = nil;
        mouseDownX = nil;

        setNeedsDisplay( bounds );
        
        let length: Double? = ( atMax == atMin ) ? nil : atMax - atMin;

        delegate?.trackCommentsView( self, requestedCommentAt: atMin, ofLength: length );
    }

}
