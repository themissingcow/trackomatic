//
//  CommentView.swift
//  Trackomatic
//
//  Created by Tom Cowland on 08/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

protocol TimelineCommentViewDelegate: class
{
    func timelineCommentView(
            _ view: TimelineCommentView,
            requestedCommentAt position: AVAudioFramePosition, ofLength length: AVAudioFramePosition?
    );
}

class TimelineCommentView: NSView {
    
    @IBInspectable var backgroundColor: NSColor = NSColor.clear;
    @IBInspectable var anchor: String = "";

    @IBOutlet var manager: CommentManager? {
        didSet {
            removeObservers( oldValue );
            addObservers( manager );
            updateDisplayComments();
        }
    };
    
    private var displayComments: [ Comment ] = [];

    var delegate: TimelineCommentViewDelegate?;

    var length: AVAudioFramePosition = 0 {
        didSet {
            self.setNeedsDisplay( bounds );
        }
    }

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
        self.displayComments = manager?.commentsFor( anchor: anchor ) ?? [];
        self.setNeedsDisplay( bounds );
    }
    
    override func draw(_ dirtyRect: NSRect) {
                        
        super.draw( dirtyRect );

        let context = NSGraphicsContext.current!.cgContext;

        context.setFillColor( backgroundColor.cgColor );
        context.fill( dirtyRect );
                    
        if length == 0
        {
            return;
        }
        
        for comment in displayComments
        {
            guard let position = comment.at else { continue; }
            
            let x = CGFloat( Double(position) / Double(length) ) * bounds.width;
            
            if let l = comment.length
            {
                let w = ( CGFloat(l) / CGFloat(length) ) * bounds.width;
                
                context.setFillColor( gray: 0.0, alpha: 0.2 );
                context.fill( CGRect( x: x, y: 0.0, width: w, height: bounds.height ) );
                
                context.setLineWidth( 1.0 );
                context.move( to: CGPoint( x: x, y: 0 ) );
                context.addLine(to: CGPoint( x: x, y: frame.height ));
                context.move( to: CGPoint( x: x + w, y: 0 ) );
                context.addLine(to: CGPoint( x: x + w, y: frame.height ));
                context.strokePath()
            }
            else
            {
                context.setLineWidth( 1.0 );
                context.move( to: CGPoint( x: x, y: 0 ) );
                context.addLine(to: CGPoint( x: x, y: frame.height ));
                context.strokePath();
            }
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
        
        let downPosition = AVAudioFramePosition( ( downX / bounds.width ) * CGFloat(length) );
        let upPosition = AVAudioFramePosition( ( upX / bounds.width ) * CGFloat(length) );
        
        let atMin = min( downPosition, upPosition );
        let atMax = max( downPosition, upPosition );
        
        mouseX = nil;
        mouseDownX = nil;

        setNeedsDisplay( bounds );
        
        let length: AVAudioFramePosition? = ( atMax == atMin ) ? nil : atMax - atMin;

        delegate?.timelineCommentView( self, requestedCommentAt: atMin, ofLength: length );
    }

}
