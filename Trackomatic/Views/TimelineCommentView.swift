//
//  CommentView.swift
//  Trackomatic
//
//  Created by Tom Cowland on 08/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

class TimelineCommentView: NSView {
    
    @IBInspectable var backgroundColor: NSColor = NSColor.clear;
    @IBInspectable var commentColor: NSColor = NSColor( white: 0.0, alpha: 0.2 );
    @IBInspectable var focusCommentColor: NSColor = NSColor( red: 0.8, green: 0.0, blue: 0.0, alpha: 0.2 );
    
    var comments: [ Comment ] = [] { didSet { setNeedsDisplay( bounds ); } };
    var focusComments: [ Comment ]? { didSet { setNeedsDisplay( bounds ); } };

    var length: Double = 0 {
        didSet {
            self.setNeedsDisplay( bounds );
        }
    }
    
    var highlightOnHover: Bool = false {
        didSet { setupTrackingArea(); }
    }
    
    // MARK: - Mouse Tracking
    
    private func setupTrackingArea()
    {
        if highlightOnHover
        {
            if highlightTrackingArea == nil
            {
                highlightTrackingArea = NSTrackingArea( rect: bounds, options: [ .activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved ], owner: self );
                addTrackingArea( highlightTrackingArea! );
            }
        }
        else
        {
            if let a = highlightTrackingArea
            {
                removeTrackingArea( a );
            }
        }
    }
    
    private var highlightTrackingArea: NSTrackingArea?;
    
    override func mouseMoved( with event: NSEvent )
    {
        let x = convert( event.locationInWindow, from: nil ).x;
        let position = Double( ( x / bounds.width ) * CGFloat(length) );
        let padding = Double( CGFloat( length ) * 0.02 );
        
        for comment in comments
        {
            let highlighted: Bool = {
                if let at = comment.at,
                   let l = comment.length
                {
                    return at <= position  && position <= ( at + l );
                }
                else if let at = comment.at
                {
                    return ( (max(at, padding) - padding) <= position ) && ( position <= (at + padding) );
                }
                return false;
            }();
            
            if highlighted != comment.highlighted
            {
                comment.highlighted = highlighted;
            }
        }
    }
    
    override func mouseExited(with event: NSEvent)
    {
        for comment in comments
        {
            if comment.highlighted
            {
                comment.highlighted = false;
            }
        }
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
                        
        super.draw( dirtyRect );

        let context = NSGraphicsContext.current!.cgContext;

        context.setFillColor( backgroundColor.cgColor );
        context.fill( dirtyRect );
                    
        if length == 0
        {
            return;
        }
        
        var haveNonTemporalComments = false;
        
        for comment in comments
        {
            guard let position = comment.at else {
                haveNonTemporalComments = true;
                continue;
            }
         
            let isFocused = focusComments?.firstIndex( of: comment ) != nil;
            let x = CGFloat( Double(position) / Double(length) ) * bounds.width;
            
            if let l = comment.length
            {
                let w = ( CGFloat(l) / CGFloat(length) ) * bounds.width;
                
                context.setFillColor( isFocused ? focusCommentColor.cgColor : commentColor.cgColor );
                context.fill( CGRect( x: x, y: 0.0, width: w, height: bounds.height ) );
            }
            else
            {
                context.setStrokeColor( isFocused ? focusCommentColor.cgColor : commentColor.cgColor );
                context.setLineWidth( 3.0 );
                context.move( to: CGPoint( x: x, y: 0 ) );
                context.addLine(to: CGPoint( x: x, y: frame.height ));
                context.strokePath();
            }
        }
        
        if haveNonTemporalComments
        {
            context.setFillColor( commentColor.cgColor );
            context.fill( CGRect( x: 0.0, y: 0.0, width: 5, height: bounds.height ) );
            context.fill( CGRect( x: bounds.width - 5.0, y: 0.0, width: 5, height: bounds.height ) );

        }
    }
}
