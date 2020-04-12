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

import Foundation

extension URL {
    
    /// Derives a string that represents the url relative to the supplied base. This can be used as a
    /// portable, human friendly refeence to the url's item.
    ///
    /// When storing a human readable persistant reference to an url's item,  anchors allow this
    /// to be made relative to some parent url (eg: data files within a project root directory). This
    /// allows the base directory to be re-loacted without invalidating any anchors.
    ///
    /// - Parameter base : Some parent of the url. If the url isn't a descendant of base,
    ///   an absolute anchor wil be generated, which doesn't support re-location.
    ///
    func anchor( relativeTo base: URL ) -> String
    {
        if !path.starts( with: base.path ) { return path; }

        let basePathLength = base.path.count;
        let pathStart = path.index( path.startIndex, offsetBy: basePathLength + 1 );
        return String( path[ pathStart... ] );
    }
    
    /// Reconstructs an URL from a human friedly reference anchor, relative to the supplied base.
    ///
    /// If the supplied anchor is absolute, then the item must still exist in the same location as when
    /// the anchor was made.
    ///
    /// - Parameter anchor: An anchor generated from `anchor(relativeTo: URL)`.
    /// - Parameter base: A root directory under which the anchor's item should be parented.
    ///
    static func fromAnchor( _ anchor: String, relativeTo base: URL ) -> URL
    {
       if anchor.starts( with: "/" )
       {
           return URL.init( fileURLWithPath: anchor );
       }
       else
       {
           return URL.init( fileURLWithPath: "\(base.path)/\(anchor)" );
       }
    }
}
