//
//  JSON.swift
//  Trackomatic
//
//  Created by Tom Cowland on 28/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Foundation

// MARK: Types

typealias JSONDict = [String: Any];

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
        load();
        
        NSFileCoordinator.addFilePresenter( self );
    }
    
    func load()
    {
        if baseDirectory == nil { return; }

        let url = jsonURL();

        var error: NSError?;
        
        let coordinator = NSFileCoordinator( filePresenter: self );
        coordinator.coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
            
            if !FileManager.default.fileExists( atPath: readUrl.path ) { return; }
            if !CacheModificationTime( url: readUrl ) { return; }
                        
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

        do
        {
            if let json: JSONDict = try LoadJSON( url: url )
            {
                loadFromDict( json, baseDirectory: baseDirectory );
            }
        }
        catch
        {
            print( "JSON load error: \(error)" );
        }
    }
    
    func save( url: URL, baseDirectory: URL )
    {
        do
        {
            let json = saveToDict( baseDirectory: baseDirectory );
            try SaveJSON( json: json, url: url );
        }
        catch
        {
            print( "JSON save error: \(error)" );
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
    
