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
    
    @objc dynamic public private(set) var audioFileGroups: [ URL: [ AVAudioFile ] ] = [:];
    
    func allAudioFiles() -> [ AVAudioFile ]
    {
        var files: [ AVAudioFile ] = [];
        for (_, groupFiles) in audioFileGroups
        {
            files.append( contentsOf: groupFiles );
        }
        return files;
    };
    
    @objc dynamic var dirty = false;
    
    // MARK: - Init
    
    override init()
    {
        uuid = UUID().uuidString;
        super.init();
    }
    
    // MARK: - Base Directory
    
    private var projectWatcher: ProjectRootWatcher?;
    private var groupWatchers: [ URL: AudioFolderWatcher ] = [:];
    
    func setBaseDirectory( directory: URL, watch: Bool )
    {
        baseDirectory = directory;
        loadAudioFiles( directory: directory );
        
        projectWatcher = ProjectRootWatcher( folder: directory, project: self );
    }
        
  
    func addGroup( url: URL )
    {
        groupWatchers[ url ] = AudioFolderWatcher( folder: url, project: self );
    }
    
    func removeGroup( url: URL, keepWatcher: Bool )
    {
        willChangeValue( forKey: "audioFileGroups" );

        audioFileGroups.removeValue( forKey: url );
        if !keepWatcher
        {
            groupWatchers.removeValue( forKey: url );
        }
        
        didChangeValue( forKey: "audioFileGroups" );

    }
    
    func setFiles( forGroup url: URL, files: [ AVAudioFile ] )
    {
        willChangeValue( forKey: "audioFileGroups" );

        audioFileGroups[ url ] = files;
        
        didChangeValue( forKey: "audioFileGroups" );
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
            groupWatchers = [:];
            audioFileGroups = [:];

            do {

                addGroup( url: directory );
                
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
                    if url == sidecarDirectory() { continue; }
                   
                    addGroup( url: url );
                }
            }
            catch
            {
               print( "\(error)" );
            }
        }
   }
}

fileprivate class ProjectRootWatcher : NSObject, NSFilePresenter
{
    var presentedItemURL: URL?;
    
    private weak var project: Project?;
    
    override init()
    {
        super.init();
        NSFileCoordinator.addFilePresenter( self );
    }
    
    deinit
    {
        NSFileCoordinator.removeFilePresenter( self );
    }
    
    convenience init( folder url: URL, project: Project )
    {
        self.init();
        
        self.project = project;
        presentedItemURL = url;
        
        project.addGroup( url: url );
        updateGroups();
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return OperationQueue.main;
    }
    
    func presentedSubitemDidAppear(at url: URL)
    {
        handle( url: url );
    }
    
    func accommodatePresentedSubitemDeletion( at url: URL, completionHandler: @escaping (Error?) -> Void)
    {
        guard let p = project else { return; }
        if p.audioFileGroups.index( forKey: url ) != nil
        {
            p.removeGroup( url: url, keepWatcher: false );
        }
    }
    
    func presentedSubitem( at oldURL: URL, didMoveTo newURL: URL )
    {
        guard let p = project else { return; }
        if p.audioFileGroups.index( forKey: oldURL ) != nil
        {
            p.removeGroup( url: oldURL, keepWatcher: false );
            p.addGroup( url: newURL );
        }
    }
   
    func accommodatePresentedItemDeletion( completionHandler: @escaping (Error?) -> Void )
    {
        // TODO: Handle project deletion
    }
    
    func presentedItemDidMove(to newURL: URL)
    {
       // TODO: Handle project dir rename
    }
    
    private func updateGroups()
    {
        if project == nil  { return; }
            
        var error: NSError?;
        NSFileCoordinator( filePresenter: self ).coordinate( readingItemAt: presentedItemURL!, options: [], error: &error ) { readUrl in
           
           do {
                let contents = try FileManager.default.contentsOfDirectory(
                   at: readUrl,
                   includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ],
                   options: [ .skipsHiddenFiles ]
                );

                for url in contents
                {
                    handle( url: url );
                }
           }
           catch
           {
               print( "Unable to list directory \(readUrl)" );
           }
        }
        if let e = error {
            print( "Coordination error: \(e)" );
        }
    }
    
    private func handle( url: URL )
    {
        guard let p = project else { return; }
        
        do
        {
            let info = try url.resourceValues(forKeys: [ .nameKey, .isDirectoryKey ] );

            if url == p.sidecarDirectory() { return; }
            if !( info.isDirectory ?? false ) { return; }

            p.addGroup( url: url );
        }
        catch
        {
            print( error );

        }
    }
}


fileprivate class AudioFolderWatcher : NSObject, NSFilePresenter
{
    var presentedItemURL: URL?;
    
    private weak var project: Project?;
    
    override init()
    {
        super.init();
        NSFileCoordinator.addFilePresenter( self );
    }
    
    deinit
    {
        NSFileCoordinator.removeFilePresenter( self );
    }
    
    convenience init( folder url: URL, project: Project )
    {
        self.init();
        
        self.project = project;
        presentedItemURL = url;
        
        updateFiles( force: true );
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return OperationQueue.main;
    }
    
    func presentedItemDidChange()
    {
        updateFiles();
    }
    
    func accommodatePresentedItemDeletion( completionHandler: @escaping (Error?) -> Void )
    {
        project?.removeGroup( url: presentedItemURL!, keepWatcher: false );
    }
    
    func presentedItemDidMove(to newURL: URL)
    {
        guard let p = project else { return; };
        
        p.removeGroup( url: presentedItemURL!, keepWatcher: false );
        if newURL.path.starts( with: p.baseDirectory!.path )
        {
            p.addGroup( url: newURL );
        }
    }
    
    private func updateFiles( force: Bool = false )
    {
        guard let p = project else { return; }
        
        var error: NSError?;
        NSFileCoordinator( filePresenter: self ).coordinate( readingItemAt: presentedItemURL!, options: [], error: &error ) { readUrl in
            
            if !force && !HasBeenModified( url: readUrl ) { return; }
           
            let files = filesFrom(directory: readUrl );
                      
            if files.count > 0
            {
                p.setFiles( forGroup: presentedItemURL!, files: files );
            }
            else
            {
                p.removeGroup( url: presentedItemURL!, keepWatcher: true );
            }
        }
        if let e = error {
            print( "Coordination error: \(e)" );
        }
    }
    
    private func filesFrom( directory: URL ) -> [ AVAudioFile ]
    {
        var files: [ AVAudioFile ] = [];

        if !FileManager.default.fileExists( atPath: directory.path ) { return files; }

        // TODO: We may want to support recursive searches here, but this complicates watching

        do {
            let contents = try FileManager.default.contentsOfDirectory(
              at: directory,
              includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ],
              options: [ .skipsHiddenFiles ]
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


