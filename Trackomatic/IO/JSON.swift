//
//  JSON.swift
//  Trackomatic
//
//  Created by Tom Cowland on 28/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Foundation
import AVFoundation

// MARK: Types

typealias JSONDict = [ String: Any ];
typealias JSONArray = [ Any ];

// MARK: Helpers

func LoadJSON<T>( url: URL ) throws -> T?
{
    if let data = FileManager.default.contents( atPath: url.path )
    {
        return try JSONSerialization.jsonObject( with: data, options: [] ) as? T;
    }
    return nil;
}

func SaveJSON<T>( json: T, url: URL ) throws
{
    let fileManager = FileManager.default;
    
    let data = try JSONSerialization.data( withJSONObject: json, options: [ .prettyPrinted ] );
    
    let dirUrl = url.deletingLastPathComponent();
    if !fileManager.fileExists( atPath: dirUrl.path )
    {
        try fileManager.createDirectory( at: dirUrl, withIntermediateDirectories: true, attributes: [:] );
    }
    
    FileManager.default.createFile( atPath: url.path, contents: data, attributes: [:] );
}


// MARK: - Project

extension Project : NSFilePresenter {
   
    convenience init( baseDirectory: URL, watch: Bool )
    {
        self.init();
       
        setBaseDirectory( directory: baseDirectory, watch: watch );
        if !load( force: true )
        {
            // Make sure we create the project json with the UUID regardless
            save();
        }
        
        NSFileCoordinator.addFilePresenter( self );
    }
    
    @discardableResult
    func load( force: Bool = false ) -> Bool
    {
        var loaded = false;
        
        if baseDirectory == nil { return loaded; }

        let url = jsonURL();

        var error: NSError?;
        
        let coordinator = NSFileCoordinator( filePresenter: self );
        coordinator.coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
            
            if !FileManager.default.fileExists( atPath: readUrl.path ) { return; }
            if !force && !HasBeenModified( url: readUrl ) { return; }
                        
            do
            {
                if let json: JSONDict = try LoadJSON( url: readUrl )
                {
                    loadFromDict( json );
                    loaded = true;
                }
            }
            catch
            {
                print( "JSON load error: \(error)" );
            }
        }
        
        if let e = error {
            print( "Coordination error: \(e)" );
        }
        
        return loaded;
    }
    
    func save()
    {
        if baseDirectory == nil { return; }
        
        let url = jsonURL();
                
        var error: NSError?;
        let coordinator = NSFileCoordinator( filePresenter: self );
        coordinator.coordinate( writingItemAt: url, options: [], error: &error ) { writeUrl in
            
            do
            {
                let json = saveToDict();
                try SaveJSON( json: json, url: writeUrl );
            }
            catch
            {
                print( "JSON save error: \(error)" );
            }
        }
        
        if let e = error {
            print( "Coordination error: \(e)" );
        }
    }
    
    func close()
    {
        NSFileCoordinator.removeFilePresenter( self );
    }

    func loadFromDict( _ json: JSONDict )
    {
        if let u = json["uuid"] as? String
        {
            uuid = u;
        }
        
        dirty = false;
    }

    private func saveToDict() -> JSONDict
    {
        var result = JSONDict();
        
        result["uuid"] = uuid;
        
        dirty = false;
        
        return result;
    }
    
    func jsonURL() -> URL
    {
        var projectFile = sidecarDirectory();
        projectFile.appendPathComponent( "project.json" );
        return projectFile;
    }
    
    func userJsonURL( tag: String, user : String? = nil ) -> URL
    {
        let u = user ?? UserDefaults.standard.string( forKey: "shortName" ) ?? NSUserName();
        var url = sidecarDirectory();
        url.appendPathComponent( "\(tag).\(u).json" );
        return url;
    }
    
    // MARK: - File Presenter
    
    var presentedItemOperationQueue: OperationQueue {
        return OperationQueue.main;
    }
    
    var presentedItemURL: URL? {
        if baseDirectory != nil
        {
            return jsonURL();
        }
        return nil;
    }
    
    func presentedItemDidChange()
    {
        load();
    }
}

// MARK: - MultiPlayer

extension MultiPlayer {
    
    func load( url: URL )
    {
        if !FileManager.default.fileExists( atPath: url.path ) { return; }

        var error: NSError?;
        NSFileCoordinator().coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
            
            do
            {
                if let json: JSONDict = try LoadJSON( url: readUrl )
                {
                    loadFromDict( json );
                }
            }
            catch
            {
                print( "JSON load error: \(error)" );
            }
        }
        if let e = error {
            print( "Coordination error: \(e)" );
        }
    }
    
    func save( url: URL )
    {
        var error: NSError?;
        NSFileCoordinator().coordinate( writingItemAt: url, options: .forReplacing, error: &error ) { writeUrl in
        
            do
            {
                let json = saveToDict();
                try SaveJSON( json: json, url: writeUrl );
            }
            catch
            {
                print( "JSON save error: \(error)" );
            }
        }
        
        if let e = error {
            print( "Coordination error: \(e)" );
        }
    }

    func loadFromDict( _ json: JSONDict )
    {
        for ( anchor, data ) in json
        {
            guard let dict = data as? JSONDict
                else { continue; }
            
            if let track = trackFor( anchor: anchor )
            {
                if let l = dict[ "loop" ] as? Bool { track.loop = l; }
                if let m = dict[ "mute" ] as? Bool { track.mute = m; }
                if let s = dict[ "solo" ] as? Bool { track.solo = s; }
                if let v = dict[ "volume" ] as? Float { track.volume = v; }
                if let p = dict[ "pan" ] as? Float { track.pan = p; }
            }
        }
        
        mixDirty = false;
    }

    private func saveToDict() -> JSONDict
    {
        var result = JSONDict();
        
        for track in tracks
        {
            guard let anchor = track.anchor() else { continue; };
            result[ anchor ] = [
                "loop" : track.loop,
                "mute" : track.mute,
                "solo" : track.solo,
                "volume" : track.volume,
                "pan" : track.pan
            ]
        }
        
        mixDirty = false;
        
        return result;
    }

}
    
// MARK: - CommentManager

extension CommentManager {
    
    func loadComments( url: URL, force: Bool = false ) -> ( [ Comment ], String )?
    {
        if !FileManager.default.fileExists( atPath: url.path ) { return nil; }

        var comments: [ Comment ]?;
        var shortName: String?
    
        do
        {
            if let json: JSONDict = try LoadJSON( url: url )
            {
                ( comments, shortName ) = loadFromDict( json );
            }
        }
        catch
        {
            print( "JSON load error: \(error)" );
        }
    
        
        if let c = comments, let s = shortName
        {
            return ( c, s );
        }
        
        return nil;
    }

    func loadFromDict( _ json: JSONDict ) -> ( [ Comment ]?, String? )
    {
        guard let shortName = json[ "shortName" ] as? String,
              let displayName = json[ "displayName" ] as? String,
              let comments = json[ "comments" ] as? JSONArray
        else {
            return ( nil, nil );
        }
    
        let userComments = shortName == userShortName;
        
        var objects: [ Comment ] = [];
        
        for data in comments
        {
            guard let dict = data as? JSONDict
                else { continue; }
            
            let comment = Comment();
            
            guard let uuid = dict[ "uuid" ] as? String else { continue; }
            comment.uuid = uuid;
            comment.shortName = shortName;
            comment.displayName = userComments ? userDisplayName : displayName;
            
            if let c = dict[ "comment" ] as? String { comment.comment = c; }
            if let a = dict[ "anchor" ] as? String { comment.anchor = a; }
            if let a = dict[ "at" ] as? AVAudioFramePosition { comment.at = a; }
            if let l = dict[ "length" ] as? AVAudioFramePosition { comment.length = l; }
            if let d = dict[ "lastEdit" ] as? Double { comment.lastEdit = Date( timeIntervalSince1970: d ); }
            comment.dirty = false;

            objects.append( comment );
        }
        
        return ( objects, shortName );
    }
    
    func save( url: URL )
     {
         var error: NSError?;
         NSFileCoordinator().coordinate( writingItemAt: url, options: .forReplacing, error: &error ) { writeUrl in
         
             do
             {
                 let json = saveToDict();
                 try SaveJSON( json: json, url: writeUrl );
             }
             catch
             {
                 print( "JSON save error: \(error)" );
             }
         }
         if let e = error {
             print( "Coordination error: \(e)" );
         }
     }

    private func saveToDict() -> JSONDict
    {
        var result = JSONDict();
        
        var commentData: JSONArray = [];
        
        for comment in commentsForUser()
        {
            var data: JSONDict = [
                "uuid" : comment.uuid,
                "comment" : comment.comment
            ]
            
            data[ "lastEdit" ] = comment.lastEdit.timeIntervalSince1970;
            if let a = comment.anchor { data[ "anchor" ] = a; }
            if let a = comment.at { data[ "at" ] = a; }
            if let l = comment.length { data[ "length" ] = l; }

            commentData.append( data );
        }
        
        result[ "comments" ] = commentData;
        result[ "shortName" ] = userShortName;
        result[ "displayName" ] = userDisplayName;
        
        userCommentsDirty = false;
        
        return result;
    }

}
    
