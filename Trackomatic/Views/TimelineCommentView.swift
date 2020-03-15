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

    var length: AVAudioFramePosition = 0 {
        didSet {
            self.setNeedsDisplay( bounds );
        }
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
        
        for comment in comments
        {
            guard let position = comment.at else { continue; }
         
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
    }
}
