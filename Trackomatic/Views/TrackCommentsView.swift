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

protocol TrackCommentsViewDelegate: AnyObject
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
