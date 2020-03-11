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

func LastModificationTime( url: URL ) -> Date?
{
    do {
        let values = try url.resourceValues( forKeys: [ .contentModificationDateKey ] );
        return values.contentModificationDate;
    }
    catch
    {
        print( "Error retrieving modification time: \(error)");
    }
    return nil;
}

private var modificationTimes: [ URL: Date ] = [:];
// Returns whether the modification time has changed since it was last cached
func CacheModificationTime( url: URL ) -> Bool
{
    if let currentModificationTime = LastModificationTime( url: url )
    {
        if let lastModificationTime = modificationTimes[ url ]
        {
            if currentModificationTime == lastModificationTime
            {
                return false;
            }
        }
        modificationTimes[ url ] = currentModificationTime;
    }
    // Default to infering change unless we're sure of the contrary
    return true;
}


// MARK: - Project

extension Project : NSFilePresenter {
   
    convenience init( baseDirectory: URL, watch: Bool )
    {
        self.init();
       
        setBaseDirectory( directory: baseDirectory, watch: watch );
        load( force: true );
        
        NSFileCoordinator.addFilePresenter( self );
    }
    
    func load( force: Bool = false )
    {
        if baseDirectory == nil { return; }

        let url = jsonURL();

        var error: NSError?;
        
        let coordinator = NSFileCoordinator( filePresenter: self );
        coordinator.coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
            
            if !FileManager.default.fileExists( atPath: readUrl.path ) { return; }
            if !force && !CacheModificationTime( url: readUrl ) { return; }
                        
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
        
        if let n = json["notes"] as? String
        {
            notes = n;
        }
        
        dirty = false;
    }

    private func saveToDict() -> JSONDict
    {
        var result = JSONDict();
        
        result["uuid"] = uuid;
        result["notes"] = notes;
        
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
    
    func load( url: URL, baseDirectory: URL )
    {
        if !FileManager.default.fileExists( atPath: url.path ) { return; }

        var error: NSError?;
        NSFileCoordinator().coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
            
            do
            {
                if let json: JSONDict = try LoadJSON( url: readUrl )
                {
                    loadFromDict( json, baseDirectory: baseDirectory );
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
    
    func save( url: URL, baseDirectory: URL )
    {
        var error: NSError?;
        NSFileCoordinator().coordinate( writingItemAt: url, options: .forReplacing, error: &error ) { writeUrl in
        
            do
            {
                let json = saveToDict( baseDirectory: baseDirectory );
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

    func loadFromDict( _ json: JSONDict, baseDirectory: URL )
    {
        for ( anchor, data ) in json
        {
            guard let dict = data as? JSONDict
                else { continue; }
            
            if let track = trackFor( anchor: anchor, baseDirectory: baseDirectory )
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

    private func saveToDict( baseDirectory: URL ) -> JSONDict
    {
        var result = JSONDict();
        
        for track in tracks
        {
            let anchor = track.anchor( baseDirectory: baseDirectory );
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

                load( url: url );
            }
        }
        catch
        {
            print( "Directory load error: \(error)" );
        }
    }
    
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
        guard let shortName = json[ "shortName" ] as? String,
              let displayName = json[ "displayName" ] as? String,
              let comments = json[ "comments" ] as? JSONArray
        else {
            return;
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
        
        add(comments: objects );
        
        if userComments
        {
            userCommentsDirty = false;
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
    
