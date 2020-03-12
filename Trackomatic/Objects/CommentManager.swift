//
//  CommentManager.swift
//  Trackomatic
//
//  Created by Tom Cowland on 08/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class CommentManager: NSObject
{
    dynamic public private(set) var comments: [ Comment ] = [];

    var userShortName: String;
    var userDisplayName: String;
    @objc dynamic var userCommentsDirty: Bool;
    
    var player: MultiPlayer?;
    
    override init()
    {
        userShortName = "";
        userDisplayName = "";
        
        userCommentsDirty = false;
    
        super.init();
        
        reset();
    }
    
    func add( comments: [ Comment ] )
    {
        for comment in comments
        {
            if let a = comment.anchor
            {
                comment.track = player?.trackFor( anchor: a );
            }
            
            addObservers( comment );
            if comment.shortName == userShortName
            {
                userCommentsDirty = true;
            }
        }
        willChangeValue( forKey: "comments" );
        self.comments.append( contentsOf: comments );
        didChangeValue( forKey: "comments" );
    }
    
    func remove( comments: [ Comment ] )
    {
        willChangeValue( forKey: "comments" );
        for comment in comments
        {
            comment.track = nil;
            if let index = self.comments.firstIndex( of: comment )
            {
                if comment.shortName == userShortName
                {
                    userCommentsDirty = true;
                }
                removeObservers( comment );
                self.comments.remove( at: index );
            }
        }
        didChangeValue( forKey: "comments" );
    }
    
    func reset()
    {
        for comment in comments
        {
            removeObservers( comment );
        }
        willChangeValue( forKey: "comments" );
        comments = [];
        didChangeValue( forKey: "comments" );
        userCommentsDirty = false;
    }
    
    func newComment( anchor: String?, add: Bool ) -> Comment
    {
        let comment = Comment();
        
        comment.anchor = anchor;
        comment.shortName = userShortName;
        comment.displayName = userDisplayName;
        
        if let a = anchor
        {
            comment.track = player?.trackFor( anchor: a );
        }
        
        if add
        {
            self.add( comments: [ comment ] );
        }
        
        return comment;
    }
    
    func commentsFor( anchor: String? ) -> [ Comment ]
    {
        return comments.filter { comment in
            return comment.anchor == anchor;
        };
    }
    
    func commentsForUser( user : String? = nil ) -> [ Comment ]
    {
        let shortName = user ?? userShortName;
        return comments.filter { comment in
            return comment.shortName == shortName;
        };
    }
    
    private func addObservers( _ comment: Comment )
    {
        comment.addObserver( self, forKeyPath: "dirty", options: [], context: nil );
    }
    
    private func removeObservers( _ comment: Comment )
    {
        comment.removeObserver( self, forKeyPath: "dirty" );
    }
    
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?
    ) {
        guard let comment = object as? Comment else { return; }
        
        if comment.shortName == userShortName
        {
            userCommentsDirty = true;
        }
    }
}
