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
    func timelineView( _ view: TimelineView, didRequestPositionChange position: AVAudioFramePosition );
}

class TimelineView: NSView {
    
    @IBInspectable var playheadColor: NSColor = NSColor.black;
    @IBInspectable var backgroundColor: NSColor = NSColor.white;
    @IBInspectable var borderColor: NSColor = NSColor.black;

    var delegate: TimelineViewDelegate?;

    var length: AVAudioFramePosition = 0 {
        didSet {
            self.setNeedsDisplay( bounds );
        }
    }
    
    var position: AVAudioFramePosition = 0 {
        didSet {
            self.setNeedsDisplay( bounds );
        }
    }

    override func draw(_ dirtyRect: NSRect) {
                        
        super.draw(dirtyRect);
            
        let context = NSGraphicsContext.current!.cgContext;

        context.setFillColor( backgroundColor.cgColor );
        context.fill( dirtyRect );
        
        context.setLineWidth( 2.0 );
        context.setStrokeColor( borderColor.cgColor );
         
        context.move( to: CGPoint( x: 0, y: 0 ) );
        context.addLine(to: CGPoint( x: 0, y: frame.height ));
        context.addLine(to: CGPoint( x: frame.width, y: frame.height ));
        context.addLine(to: CGPoint( x: frame.width, y: 0 ));
        context.strokePath()
            
        if length == 0
        {
            return;
        }
        
        let x = CGFloat( Double(position) / Double(length) ) * frame.width;
        
        context.setLineWidth( 4.0 );
        context.setStrokeColor( playheadColor.cgColor );
        context.move( to: CGPoint( x: x, y: 0 ) );
        context.addLine(to: CGPoint( x: x, y: frame.height ));
        context.strokePath()
        
     
    }
    
    override func mouseDown(with event: NSEvent)
    {
        let p = convert( event.locationInWindow, to: self );
        let xx = p.x - frame.minX;
        delegate?.timelineView( self, didRequestPositionChange: AVAudioFramePosition( ( ( xx ) / frame.width ) * CGFloat(length) ) );
    }
        
}
