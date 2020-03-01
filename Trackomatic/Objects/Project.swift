//
//  Project.swift
//  Trackomatic
//
//  Created by Tom Cowland on 28/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import AVFoundation
import Cocoa
import Foundation

class Project: NSObject {
    
    var uuid: String;
    @objc dynamic var notes: String = "";
    
    @objc dynamic public private(set) var baseDirectory: URL?
    
    @objc dynamic var audioFiles: [ AVAudioFile ] = [];
    @objc dynamic var audioFileGroups: [ URL: [ AVAudioFile ] ] = [:];
    
    var fileCoordinator = NSFileCoordinator();

    // MARK: - Init
    
    override init()
    {
        uuid = UUID().uuidString;
    }
    
    // MARK: - Base Directory
    
    func setBaseDirectory(directory: URL)
    {
        loadAudioFiles( directory: directory );
        baseDirectory = directory;
    }
    
    // MARK: - Support files
    
    func sidecarDirectory() -> URL
    {
       return baseDirectory!.appendingPathComponent( "Trackomatic", isDirectory: true );
    }
    
    // MARK: - Load Audio
    
    func loadAudioFiles( directory: URL )
    {
        var files: [ AVAudioFile ] = [];
        var groups: [ URL: [ AVAudioFile ] ] = [:];

        do {
            let topLevelFiles = audioFilesFrom( directory: directory, recursive: false );

            files.append( contentsOf: topLevelFiles );
            groups[ directory ] = topLevelFiles;
           
           let dirContents = try FileManager.default.contentsOfDirectory(
               at: directory,
               includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ],
               options: [ .skipsSubdirectoryDescendants, .skipsHiddenFiles ]
           );
           
           // Load subdirectories as groups
           for url in dirContents
           {
                let info = try url.resourceValues(forKeys: [ .nameKey, .isDirectoryKey ] );
                if !info.isDirectory! { continue; }
               
                let dirFiles = audioFilesFrom( directory: url, recursive: true );
                if( dirFiles.count > 0 )
                {
                    files.append( contentsOf: dirFiles );
                    groups[ url ] = dirFiles;
                }
            }
        }
        catch
        {
           print( "\(error)" );
        }
       
        audioFiles = files;
        audioFileGroups = groups;
   }
   
   func audioFilesFrom( directory: URL, recursive: Bool = true ) -> [ AVAudioFile ]
   {
       var files: [ AVAudioFile ] = [];

       // TODO: Move to FileManager.enumerate as contentsOfDirectory is shallow so recursive is broken
       
       do {
           let contents = try FileManager.default.contentsOfDirectory(
               at: directory,
               includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ],
               options: recursive ? [ .skipsHiddenFiles ] : [ .skipsHiddenFiles, .skipsSubdirectoryDescendants ]
           );
           
           let suppportedExtensions = Set( [ "aif", "wav", "mp3", "m4a" ] );

           for url in contents
           {
               let info = try url.resourceValues(forKeys: [ .nameKey, .isDirectoryKey ] );
               
               if info.isDirectory! { continue; }
               if !suppportedExtensions.contains( url.pathExtension ) { continue; }
               
               do {
                   let file = try AVAudioFile(forReading: url );
                   files.append( file );
               }
               catch
               {
                   print( "Unable to load audio file \(url)" );
               }
           }
       }
       catch
       {
           print( "Unable to list directory \(directory)" );

       }
       
       files.sort { (a, b) in a.url.lastPathComponent < b.url.lastPathComponent; }
       
       return files;
   }
    
}
