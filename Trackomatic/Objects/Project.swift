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
    @objc dynamic var notes: String = "" {
        didSet {
            if notes != oldValue {
                dirty = true;
            }
        }
    }
    
    @objc dynamic public private(set) var baseDirectory: URL?
    
    @objc dynamic var audioFiles: [ AVAudioFile ] = [];
    @objc dynamic var audioFileGroups: [ URL: [ AVAudioFile ] ] = [:];
    
    @objc dynamic var dirty = false;
    
    // MARK: - Init
    
    override init()
    {
        uuid = UUID().uuidString;
    }
    
    // MARK: - Base Directory
    
    private var dirWatcher: Watcher?;
    
    func setBaseDirectory( directory: URL, watch: Bool )
    {
        loadAudioFiles( directory: directory );
        baseDirectory = directory;
        
        dirWatcher = nil;
        if watch
        {
            dirWatcher = Watcher( url: directory ) { _, event in
                if event == DispatchSource.FileSystemEvent.write
                {
                    if let dir = self.baseDirectory
                    {
                        self.loadAudioFiles( directory: dir, debounceDelay: 2.0 );
                    }
                }
            }
        }
    }
    
    // MARK: - Support files
    
    func sidecarDirectory() -> URL
    {
       return baseDirectory!.appendingPathComponent( "Trackomatic", isDirectory: true );
    }
    
    // MARK: - Load Audio
    // TODO: Not sure that debouncing should be here really
    private var loadAudioFilesDebounceTimer: Timer?;
    func loadAudioFiles( directory: URL, debounceDelay: Double = 0.0 )
    {
        if debounceDelay > 0.0
        {
            loadAudioFilesDebounceTimer?.invalidate();
            loadAudioFilesDebounceTimer = Timer.scheduledTimer(
                withTimeInterval: debounceDelay, repeats: false
            ) { _ in
                self.loadAudioFiles( directory: directory );
            }
        }
        else
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
