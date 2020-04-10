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

class CommentsViewController: NSViewController
{
    @objc dynamic var commentManager: CommentManager? {
        didSet
        {
            if let old = oldValue
            {
                old.removeObserver( self, forKeyPath: "comments" );
            }
            if let new = commentManager
            {
                new.addObserver( self, forKeyPath: "comments", options: [], context: nil );
            }
            update();
        }
    };
    
    @objc dynamic var anchor: String? {
        didSet
        {
            update();
        }
    };
    
    @IBOutlet weak var stackView: CommentsStackView!
    private var commentViewControllers : [ CommentViewController ] = [];
    
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "comments"
        {
            update();
        }
    }
    
    override func viewDidLoad()
    {
        update();
    }
    
    private func update()
    {
        if !isViewLoaded { return; }
        
        // Very naiive implementation for now
        
        for vc in commentViewControllers
        {
            stackView.removeView( vc.view );
        }
        
        commentViewControllers.removeAll();
        
        guard let manager = commentManager else { return; }
        
        guard let sb = storyboard else { return; }
        
        var comments = manager.commentsFor( anchor: anchor );
        
        comments.sort { ( a, b ) -> Bool in
            return a.lastEdit > b.lastEdit;
        }
        
        for comment in comments
        {
            let vc = sb.instantiateController( withIdentifier: "commentViewController" ) as! CommentViewController;
            vc.comment = comment;
            vc.editable = comment.shortName == commentManager?.userShortName;
            commentViewControllers.append( vc );
            stackView.addArrangedSubview( vc.view );
        }
    }
}

class CommentsStackView : NSStackView
{
    override var isFlipped: Bool { return true; }
}
