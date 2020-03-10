//
//  CommentViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 10/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class CommentViewController: NSViewController
{
    enum Mode {
        case new;
        case existing;
    }
    
    var mode: Mode = .existing;
    
    @objc dynamic var comment: Comment? {
        willSet { willChangeValue(forKey: "editable"); willChangeValue( forKey: "deletable" ); }
        didSet { didChangeValue( forKey: "editable"); didChangeValue( forKey: "deletable" ); }
    };
    
    @objc dynamic var manager: CommentManager? {
           willSet { willChangeValue(forKey: "editable"); willChangeValue( forKey: "deletable" ); }
           didSet { didChangeValue( forKey: "editable"); didChangeValue( forKey: "deletable" ); }
    };
    
    @objc dynamic var editable: Bool {
        return comment != nil && ( comment?.shortName == manager?.userShortName );
    }
    
    @objc dynamic var deletable: Bool {
        return editable && mode != .new;
    }
    
    @IBAction func delete( _ sender: Any )
    {
        guard let c = comment else { return };
        comment = nil;
        manager?.remove(comments: [ c ] );
    }
}
