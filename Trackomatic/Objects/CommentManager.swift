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

class CommentManager: NSObject
{
    dynamic public private(set) var comments: [ Comment ] = [];

    var userShortName: String;
    var userDisplayName: String;
    @objc dynamic var userCommentsDirty: Bool;
    
    var player: MultiPlayer?;
    
    fileprivate var presenters: [ URL: CommentPresenter ] = [:];
    
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
            comment.manager = self;
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
            comment.manager = nil;
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
    
    func load( directory: URL, tag: String )
    {
        do
        {
            let dirContents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ],
                options: [ .skipsHiddenFiles ]
            );
            
            for url in dirContents
            {
                let info = try url.resourceValues(forKeys: [ .nameKey, .isDirectoryKey ] );
                if info.isDirectory! || !info.name!.starts( with: tag ) { continue; }

                var error: NSError?;
                NSFileCoordinator().coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
                          
                    HasBeenModified( url: readUrl );
                
                    guard let ( comments, name ) = loadComments( url: url ) else { return; }
                    
                    add( comments: comments );
                    
                    if name == userShortName
                    {
                        userCommentsDirty = false;
                    }
                    else
                    {
                        presenters[ url ] = CommentPresenter( commentFile: url, shortName: name, commentManager: self );
                    }
                }
                if let e = error {
                    print( "Coordination error: \(e)" );
                }
            }
        }
        catch
        {
            print( "Directory load error: \(error)" );
        }
    }
}

fileprivate class CommentPresenter : NSObject, NSFilePresenter
{
    var presentedItemURL: URL?;
    
    private weak var manager: CommentManager?;
    private var name = "";
    
    override init()
    {
        super.init();
        NSFileCoordinator.addFilePresenter( self );
    }
    
    deinit
    {
        NSFileCoordinator.removeFilePresenter( self );
    }
    
    convenience init( commentFile url: URL, shortName: String, commentManager: CommentManager )
    {
        self.init();
        
        name = shortName;
        manager  = commentManager;
        presentedItemURL = url;
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return OperationQueue.main;
    }
    
    func presentedItemDidChange()
    {
        guard let m = manager else { return; }
        
        var error: NSError?;
        NSFileCoordinator().coordinate( readingItemAt: presentedItemURL!, options: [], error: &error ) { readUrl in
                 
            if !HasBeenModified( url: readUrl ) { return; }
            
            guard let ( comments, name ) = m.loadComments( url: readUrl ) else { return; }

            if name != self.name { return; }
            
            let oldComments = m.commentsForUser( user: name );
            if !oldComments.isEmpty
            {
                m.remove( comments: oldComments );
            }
            
            m.add( comments: comments );
        }
    }
    
    func accommodatePresentedItemDeletion( completionHandler: @escaping (Error?) -> Void )
    {
        guard let m = manager else { return; }
        
        let comments = m.commentsForUser( user: name );
        if !comments.isEmpty
        {
            m.remove( comments: comments );
        }
    }
}

