//
//  TimelineView.swift
//  Trackomatic
//
//  Created by Tom Cowland on 26/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

protocol TimelineViewDelegate: class {
    func timelineView( _ view: TimelineView, didRequestPositionChange position: Double );
}

class TimelineView: NSView {
    
    @IBInspectable var playheadColor: NSColor = NSColor.black;
    @IBInspectable var playheadWidth: CGFloat = 1.0;
    
    @IBInspectable var drawBorder: Bool = false;
    @IBInspectable var borderColor: NSColor = NSColor.black;
    
    @IBInspectable var backgroundColor: NSColor = NSColor.clear;

    var delegate: TimelineViewDelegate?;

    var length: Double = 0 {
        didSet {
            self.setNeedsDisplay( bounds );
        }
    }
    
    var position: Double = 0 {
        didSet {
            self.setNeedsDisplay( bounds );
        }
    }

    override func draw(_ dirtyRect: NSRect) {
                        
        super.draw(dirtyRect);

        let context = NSGraphicsContext.current!.cgContext;

        context.setFillColor( backgroundColor.cgColor );
        context.fill( dirtyRect );
        
        if drawBorder
        {
            context.setLineWidth( 2.0 );
            context.setStrokeColor( borderColor.cgColor );
             
            context.move( to: CGPoint( x: 0, y: 0 ) );
            context.addLine(to: CGPoint( x: 0, y: frame.height ));
            context.addLine(to: CGPoint( x: frame.width, y: frame.height ));
            context.addLine(to: CGPoint( x: frame.width, y: 0 ));
            context.strokePath()
        }
            
        if length == 0
        {
            return;
        }
        
        let x = CGFloat( position / length ) * frame.width;
        
        context.setLineWidth( playheadWidth );
        context.setStrokeColor( playheadColor.cgColor );
        context.move( to: CGPoint( x: x, y: 0 ) );
        context.addLine(to: CGPoint( x: x, y: frame.height ));
        context.strokePath()
        
     
    }
    
    override func mouseDown(with event: NSEvent)
    {
        if let d = delegate
        {
            let p = convert( event.locationInWindow, from: nil );
            let pos = Double( ( p.x / frame.width ) * CGFloat(length) );
            d.timelineView( self, didRequestPositionChange: pos );
        }
        else
        {
            super.mouseDown( with: event );
        }
    }
        
}
