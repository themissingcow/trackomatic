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
