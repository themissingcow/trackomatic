//
//  Comment.swift
//  Trackomatic
//
//  Created by Tom Cowland on 08/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

class Comment: NSObject {
    
    dynamic var uuid: String;

    @objc dynamic var shortName: String { didSet { dirty = true; } };
    @objc dynamic var displayName: String { didSet { dirty = true; } };
    
    @objc dynamic var anchor: String? { didSet { dirty = true; } };
    
    dynamic var at: AVAudioFramePosition? { didSet { dirty = true; } };
    dynamic var length: AVAudioFramePosition? { didSet { dirty = true; } };
    
    @objc dynamic var comment: String { didSet { dirty = true; } };
        
    dynamic var dirty: Bool;

    override init()
    {
        uuid = UUID().uuidString;
        
        shortName = "";
        displayName = "";
        
        comment = "";
        
        dirty = false;
        
        super.init();
    }
}
