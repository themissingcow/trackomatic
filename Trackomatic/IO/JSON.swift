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

        do
        {
            if let json: JSONDict = try LoadJSON( url: jsonURL() )
            {
                loadFromDict( json );
            }
        }
        catch
        {
            print( "JSON load error: \(error)" );
        }
    }
    
    func save()
    {
        if baseDirectory == nil { return; }
        
        do
        {
            let json = saveToDict();
            try SaveJSON( json: json, url: jsonURL() );
        }
        catch
        {
            print( "JSON save error: \(error)" );
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

}
