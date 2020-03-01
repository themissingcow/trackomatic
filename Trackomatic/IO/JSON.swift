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

// MARK: - Project

extension Project {
        
    convenience init( baseDirectory: URL )
    {
        self.init();
       
        setBaseDirectory( directory: baseDirectory );
        load();
    }
    
    func load()
    {
        if baseDirectory == nil { return; }

        let url = jsonURL();

        var error: NSError?;
        fileCoordinator.coordinate( readingItemAt: url, options: [], error: &error ) { readUrl in
            
            if !FileManager.default.fileExists( atPath: readUrl.path ) { return; }
            
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
        fileCoordinator.coordinate( writingItemAt: url, options: .forReplacing, error: &error ) { writeUrl in
            
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
        if let u = json["uuid"] as? String
        {
            uuid = u;
        }
        
        if let n = json["notes"] as? String
        {
            notes = n;
        }
    }

    private func saveToDict() -> JSONDict
    {
        var result = JSONDict();
        
        result["uuid"] = uuid;
        result["notes"] = notes;
        
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
        for ( relPath, data ) in json
        {
            guard let dict = data as? JSONDict
                else { continue; }
            
            let trackURL = URL.init( fileURLWithPath: "\(baseDirectory.path)/\(relPath)" );
            if let track = trackFor( url: trackURL )
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
        let basePathLength = baseDirectory.path.count;
        
        var result = JSONDict();
        
        for track in tracks
        {
            let path = track.file.url.path;
            let pathStart = path.index( path.startIndex, offsetBy: basePathLength + 1 );
            let relPath = String( track.file.url.path[ pathStart... ] );
            
            result[ relPath ] = [
                "loop" : track.loop,
                "mute" : track.mute,
                "solo" : track.solo,
                "volume" : track.volume,
                "pan" : track.pan
            ]
        }
        
        return result;
    }

}
    
