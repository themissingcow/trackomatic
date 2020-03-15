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
    
    @objc dynamic var lastEdit: Date { didSet { dirty = true; } }

    @objc dynamic var shortName: String { didSet { dirty = true; } };
    @objc dynamic var displayName: String { didSet { dirty = true; } };
    
    @objc dynamic var anchor: String? { didSet { dirty = true; } };
    
    dynamic var at: AVAudioFramePosition? { didSet { dirty = true; } };
    dynamic var length: AVAudioFramePosition? { didSet { dirty = true; } };
    
    @objc dynamic var comment: String { didSet {
        dirty = true;
        lastEdit = Date();
    } };
    
    var track: MultiPlayer.Track?;

    @objc dynamic var dirty: Bool;
    
    weak var manager: CommentManager?;

    func delete()
    {
        manager?.remove( comments: [ self ] );
    }

    override init()
    {
        uuid = UUID().uuidString;
        
        lastEdit = Date();
        
        shortName = "";
        displayName = "";
        
        comment = "";
        
        dirty = false;
        
        super.init();
    }
}
