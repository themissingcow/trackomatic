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

import AVFoundation
import Cocoa
import Foundation

class Project: NSObject {
    
    var uuid: String;
    
    var sampleRate: Double = 44100.0 {
        didSet {
            dirty = true;
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
    
    // MARK: - Sample Rate
    
    func commonSampleRate() -> Double?
    {
        let files = allAudioFiles();
        
        if files.isEmpty {
            return nil;
        }

        let rate = files.first!.fileFormat.sampleRate;
        for file in files
        {
            if file.fileFormat.sampleRate != rate
            {
                return nil;
            }
        }
        
        return rate;
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
    
    func presentedItemDidChange()
    {
        // This gets called whenever the hierarchy underneath the root folder
        // changes. I think this is due to modification time propogation.
        // Methods like presentedSubitemDidAppear, etc... are not neccesarily
        // called however.
        updateGroups();
    }
    
    func presentedSubitemDidAppear( at url: URL )
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
        guard let p = project, let u = presentedItemURL else { return; }
        if p.audioFileGroups.index( forKey: u ) != nil
        {
            p.removeGroup( url: u, keepWatcher: false );
        }
        presentedItemURL = nil;
    }
    
    func presentedItemDidMove(to newURL: URL)
    {
        guard let p = project else { return; }
        p.setBaseDirectory( directory: newURL, watch: true );
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

            // We only add an audio file group if we don't have it already. If we do
            // it will already have a watcher and be taking care of child changes itself.
            if p.audioFileGroups.index( forKey: url ) == nil
            {
                p.addGroup( url: url );
            }
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
    
    func presentedSubitemDidAppear(at url: URL) {
        updateFiles();
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


