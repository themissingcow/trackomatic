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

protocol TimelineViewDelegate: AnyObject {
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
