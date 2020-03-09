//
//  TrackRowView.swift
//  Trackomatic
//
//  Created by Tom Cowland on 09/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class TrackRowView: NSTableRowView {

    override func draw( _ dirtyRect: NSRect )
    {
        super.draw( dirtyRect );

        if isSelected == true
        {
            NSColor.selectedContentBackgroundColor.highlight( withLevel: 0.9 )!.set();
            var fillRect = dirtyRect;
            fillRect.origin.y -= 1;
            fillRect.fill()
        }
    }

}
