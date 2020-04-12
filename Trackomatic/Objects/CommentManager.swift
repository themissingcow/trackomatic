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
    
    private var watcher: CommentsFolderWatcher?;
    
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
        watcher = CommentsFolderWatcher( folder: directory, tag: tag, commentManager: self );
    }
}

fileprivate class CommentsFolderWatcher : NSObject, NSFilePresenter
{
    var presentedItemURL: URL?;
    
    private var presenters: [ URL: CommentPresenter ] = [:];
    private var userCommentsURL: URL?;
    
    private weak var manager: CommentManager?;
    
    private var tag: String = "comments";
    
    override init()
    {
        super.init();
        NSFileCoordinator.addFilePresenter( self );
    }
    
    deinit
    {
        NSFileCoordinator.removeFilePresenter( self );
    }

    convenience init( folder url: URL, tag: String, commentManager: CommentManager )
    {
        self.init();
     
        self.tag = tag;
        manager = commentManager;
        presentedItemURL = url;

        updateComments( initialLoad: true );
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return OperationQueue.main;
    }
    
    func presentedItemDidChange()
    {
        updateComments( initialLoad: false );
    }
    
    func presentedSubitemDidAppear( at url: URL )
    {
        handle( url: url, initialLoad: false );
    }
        
    func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void)
    {
        if let i = presenters.index( forKey: url )
        {
            presenters.remove( at: i );
        }
    }
   
    func accommodatePresentedItemDeletion( completionHandler: @escaping (Error?) -> Void )
    {
        guard let m = manager else { return; }
        m.reset();
    }
    
    func presentedItemDidMove(to newURL: URL)
    {
        // We don't presently support moving the whole thing whilst the app is open.
        guard let m = manager else { return; }
        m.reset();
    }
    
    func updateComments( initialLoad: Bool )
    {
        do
        {
            let dirContents = try FileManager.default.contentsOfDirectory(
                at: presentedItemURL!,
                includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ],
                options: [ .skipsHiddenFiles ]
            );
            
            for url in dirContents
            {
                handle( url: url, initialLoad: initialLoad );
            }
        }
        catch
        {
            print( "updateComments error: \(error)" );
        }
    }
    
    private func handle( url: URL, initialLoad: Bool )
    {
        // TODO: Need to refactor all this
        
        guard let m = manager else { return; }
        
        // Already managed by a CommentPresenter
        if presenters.index( forKey: url ) != nil || userCommentsURL == url { return; }
        
        do {
            let info = try url.resourceValues(forKeys: [ .nameKey, .isDirectoryKey ] );
            if info.isDirectory! || !info.name!.starts( with: tag ) { return; }

            var error: NSError?;
            NSFileCoordinator().coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
                      
                // Store last access time. We don't need to early out here as the logic below ensures
                // we only load the user comments the first time. No-change optimisation is taken care of
                // in CommentPresenter, we just have to special case user comments as we don't need to
                // watch those, as we're in charge of them.
                
                HasBeenModified( url: readUrl );
            
                guard let ( comments, name ) = m.loadComments( url: url ) else { return; }
                
                if name == m.userShortName
                {
                    // We only load the comments from the file if there are non already, as we'll be
                    // in a 'first load' scenario. Otherwise, if we end up here later, its because the
                    // user's comments have been saved for the first time.
                    if initialLoad
                    {
                        m.add( comments: comments );
                        m.userCommentsDirty = false;
                    }
                    userCommentsURL = url;
                }
                else
                {
                    presenters[ url ] = CommentPresenter( commentFile: url, shortName: name, commentManager: m );
                }
            }
            if let e = error {
                print( "Coordination error: \(e)" );
            }
        }
        catch
        {
            print( "Comment load error: \(error)" );
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
        removeComments();
    }
    
    convenience init( commentFile url: URL, shortName: String, commentManager: CommentManager )
    {
        self.init();
        
        name = shortName;
        manager  = commentManager;
        presentedItemURL = url;
        
        updateComments( force: true );
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return OperationQueue.main;
    }
    
    func presentedItemDidChange()
    {
        updateComments( force: false );
    }
    
  
    func accommodatePresentedItemDeletion( completionHandler: @escaping (Error?) -> Void )
    {
        removeComments();
    }

    func presentedItemDidMove(to newURL: URL)
    {
        // We don't support renaming comment files as of now
        removeComments();
    }
    
    func updateComments( force: Bool )
    {
        guard let m = manager else { return; }

        var error: NSError?;
        NSFileCoordinator().coordinate( readingItemAt: presentedItemURL!, options: [], error: &error ) { readUrl in
               
            if !force && !HasBeenModified( url: readUrl ) { return; }

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
    
    private func removeComments()
    {
        guard let m = manager else { return; }
        
        let comments = m.commentsForUser( user: name );
        if !comments.isEmpty
        {
            m.remove( comments: comments );
        }
    }
}

