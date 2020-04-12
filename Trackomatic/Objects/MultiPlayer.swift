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

import Cocoa
import AVFoundation

/// Provides sample-accurate playback of one or more audio files that all start at the same logical point.
/// Each track features basic volume, pan, mute and solo controls along with a loop option that allows
/// the file to be repeated ad-nausiem.
///
/// The player itself is configured for a specific sample rate, automatic SRC is applied to any source files
/// that are not at this rate.  When mixed rates are used there may be small syncronisation errors between
/// files of different rates when when playing from points other than the start.
///
class MultiPlayer : NSObject {

    /// Sets the base sample rate for the player's audio engine.
    ///
    /// Any files not at the rate will be converted on-the-fly during playback.
    ///
    /// - Important: If true sample accurate playback is required, mix rates should not be used,
    ///   and the player sample rate set to the files' rate.
    ///
    @objc dynamic var sampleRate: Double = 44100.0    { didSet{ setSampleRate(); } }
    
    // MARK: - Files
    
    /// Set  to the list of files to play. Updating the array in place will have no effect.
    var files: [ AVAudioFile ] = []    { didSet { if files != oldValue { setupFrom( files: files ); } } };
    
    /// @group Tracks
    /// @{
    
    // MARK: - Tracks

    /// Represents a single audio file being played by a MultiPlayer instance.
    ///
    /// The Track object provides control over the files playback volume, panning, and loop state.
    ///
    class Track : NSObject {
        
        @objc dynamic var volume: Float = 1.0  { didSet { player.volume = volume; } }
        @objc dynamic var pan: Float = 0.0     { didSet { player.pan = pan; } }
        
        /// Looped tracks repeat ad-nausium
        @objc dynamic var loop = false;
        /// A muted track does not play unless it is solo'd.
        @objc dynamic var mute = false;
        /// Setting solo on one or more tracks overrides any existing mutes.
        @objc dynamic var solo = false;

        /// The length of the track's audio file in seconds.
        var duration: Double                   { return Double(file.length) / file.fileFormat.sampleRate; }
        
        /// The track's audio file.
        @objc dynamic public fileprivate(set) var file: AVAudioFile!;
        /// The player this track belongs to.
        @objc dynamic weak public fileprivate(set) var parent: MultiPlayer!;
       
        // Tracks make use of a player, and a mute mixer. The mute mixer is used to
        // implement mute/solo without needing do juggle the tracks actual volume.
        
        fileprivate var player: AVAudioPlayerNode!;
        fileprivate var muteMixer: AVAudioMixerNode!;
    }

    @objc dynamic public private(set) var tracks: [ Track ] = [];

    /// - Returns: The player's track for the supplied audio file or nil if the player has no matching track.
    func trackFor( file: AVAudioFile ) -> Track?
    {
        return tracks.first { track in
            return track.file == file;
        }
    }
    
    /// - Returns: the player's track playing the specified url or nil if the player has no matching track.
    func trackFor( url: URL ) -> Track?
    {
        return tracks.first { track in
            return track.file.url == url;
        }
    }
    
    /// @}
    

    /// @Group Mix
    /// @{

    // MARK: - Mix
    
    /// An observable var that can be used to track changes to the players mix.
    ///
    /// It will be set to true whenever a tracks playback properties are adjusted. Code managing a player is
    /// free to set this to false as and when any changes have been handled, for example, after saving the
    /// mix to some persistant state.
    ///
    @objc dynamic var mixDirty = false;
        
    /// Resets the player's mix to default unity gain, center pan, clears mute/solo/loop flags.
    func resetMix()
    {
        for track in tracks {
            track.volume = 1.0;
            track.pan = 0.0;
            track.loop = false;
            track.mute = false;
            track.solo = false;
        }
        mixDirty = false;
    }
    
    /// Unmutes all tracks, solo state is unchanged.
    func clearMutes()
    {
        for track in tracks {
            track.mute = false;
        }
    }
    
    /// Un solo's all tracks, mute state is unchanged.
    func clearSolos()
    {
        for track in tracks {
            track.solo = false;
        }
    }
    
    /// @}
    
    /// @group Transport Control
    /// @{
    
    // MARK: - Transport Control

    /// The length of the longest track, in seconds
    @objc dynamic var duration: Double     { return Double( frameLength ) / sampleRate; }
    
    /// An observable property denoting whether the player is playing or not
    @objc dynamic var playing: Bool = false;
    
    /// The current playback position of the player, in seconds
    var currentTime: Double
    {
       if let player = keyPlayer, let time = player.lastRenderTime
       {
            var sampleTime = lastPlayStart;
            if time.isSampleTimeValid
            {
               sampleTime += ( player.playerTime( forNodeTime: time )?.sampleTime ?? 0 );
            }
            return Double( sampleTime ) / sampleRate;
       }
       return 0;
    }
    
    /// Starts playback at the beginning, or at some other specified point.
    ///
    /// - Parameter time: The start point for playback in seconds.
    ///
    func play( atTime time: Double = 0 )
    {
        play( atFrame: AVAudioFramePosition( time * sampleRate ), schedule: true );
    }
    
    /// Stops playback, leaving the current time unchanged.
    func stop()
    {
        playing = false;
        for track in tracks
        {
            track.player.stop();
        }
    }
    
    /// @}
    
    
    /// @group Bounce to disk
    /// @{
    
    // MARK: - Bounce-to-disk

    /// Settings for uncompressed 24bit PCM AIFF audio.
    func aiffSettings() -> [ String: Any ]
    {
        var settings: [ String: Any ] = [:];
        settings[ AVFormatIDKey ] = kAudioFormatLinearPCM;
        settings[ AVSampleRateKey ] = audioFormat.sampleRate;
        settings[ AVNumberOfChannelsKey ] = audioFormat.channelCount;
        settings[ AVLinearPCMBitDepthKey ] = 24;
        return settings;
    }
    
    /// Renders the current mix to disk.
    ///
    /// The resulting file will be the length of the longest track and the current player sample rate.
    ///
    ///  - Parameter url: A  file url for the resulting audio file.
    ///  - Parameter settings : Suitable encoding settings, \see aiffSettings
    ///
    func renderTo( output url: URL, settings: [ String: Any ] )
    {
        stop();
        engine.stop();
        
        do {
            let maxFrames: AVAudioFrameCount = 4096;
            try engine.enableManualRenderingMode( .offline, format: audioFormat, maximumFrameCount: maxFrames );
            try engine.start();
            play( atFrame: 0, schedule: false );
        } catch {
            fatalError("Enabling manual rendering mode failed: \(error).")
        }
        
        let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        )!

        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile( forWriting: url, settings: settings );
        } catch {
            print("Unable to open output audio file: \(error).")
            return;
        }
        
        while engine.manualRenderingSampleTime < frameLength
        {
            do
            {
                let frameCount = frameLength - engine.manualRenderingSampleTime;
                let framesToRender = min( AVAudioFrameCount(frameCount), buffer.frameCapacity );
                
                let status = try engine.renderOffline( framesToRender, to: buffer );
                
                switch status {
                    
                    case .success:
                        try outputFile.write( from: buffer );
                        
                    case .cannotDoInCurrentContext:
                        // The engine couldn't render in the current render call.
                        // Retry in the next iteration.
                        break
                        
                    case .error:
                        fatalError("The manual rendering failed.");
                    
                    default:
                        break;
                }
                
            } catch {
                print("The manual rendering failed: \(error).");
            }
        }

        stop();
        engine.stop()
        engine.disableManualRenderingMode();
        
        do
        {
            try engine.start();
        }
        catch
        {
            print("Unable to restart audio engine: \(error).");
        }
    }
    
    /// @}
    
    // MARK: - IMPLEMENTATION

    // Public visibility is for test harness
    
    public private(set) var audioFormat: AVAudioFormat!;
    
    private var engine: AVAudioEngine;
    public private(set) var mixer: AVAudioMixerNode;
    
    // The key player is that of the longest track
    private var keyPlayer: AVAudioPlayerNode?;
    // Used to calculate the current position, as the player timeline is not stable
    private var lastPlayStart: AVAudioFramePosition;
        
    override init()
    {
        lastPlayStart = 0;

        engine = AVAudioEngine();
        mixer = AVAudioMixerNode();
        engine.attach( mixer );
        
        super.init();

        setSampleRate();
    }
    
    private func setSampleRate()
    {
        stop();
        
        setupFrom( files: [] );
        
        engine.stop();
        
        audioFormat = AVAudioFormat( standardFormatWithSampleRate: sampleRate, channels: 2 )!;
        engine.disconnectNodeOutput( mixer );
        engine.connect( mixer, to: engine.outputNode, fromBus: 0, toBus: 0, format: audioFormat );
        
        setupFrom( files: files );
        
        do
        {
            try self.engine.start();
        }
        catch
        {
            print( "Error initialising engine: \(error)" );
        }
    }
    
    // Sets up the players Tracks to play the supplied files,
    // applies automatic looping to short files.
    private func setupFrom( files: [ AVAudioFile ] )
    {
        willChangeValue( forKey: "tracks" );
        
        ensureTracks( count: files.count );
        
        frameLength = 0;
        keyPlayer = nil;
        resetMix();

        for ( index, file ) in files.enumerated()
        {
            tracks[ index ].file = file;
            
            let fileFrameLength = file.length( atSampleRate: sampleRate );
            if fileFrameLength > frameLength
            {
                frameLength = fileFrameLength;
                keyPlayer = tracks[ index ].player;
            }
        }
        
        for track in tracks
        {
            // Automaticlly turn on loop for relatively short files
            if track.duration < ( duration / 2.1 )
            {
                track.loop = true;
            }
        }
        
        didChangeValue( forKey: "tracks" );
    }
    
    // Ensures we have n tracks connected into the audio engine and suitably
    // observed. If we have more than n, unused tracks will be removed.
    private func ensureTracks( count: Int )
    {
        while tracks.count > count
        {
            let track = tracks.popLast()!;

            track.player.stop();
            engine.disconnectNodeOutput( track.player );
            engine.detach( track.player );

            engine.disconnectNodeOutput( track.muteMixer );
            engine.detach( track.muteMixer );

            removeObservers( track: track );
        }
            
        while tracks.count < count
        {
            let track = Track();
            track.parent = self;

            track.player = AVAudioPlayerNode();
            engine.attach( track.player );

            track.muteMixer = AVAudioMixerNode();
            engine.attach( track.muteMixer );

            addObservers( track: track );
            tracks.append( track );

            engine.connect( track.player, to: track.muteMixer, fromBus: 0, toBus: 0, format: audioFormat );
            engine.connect( track.muteMixer, to: mixer, fromBus: 0, toBus: tracks.count - 1, format: audioFormat );
        }
    }
    
    // We use frames internally so we can maintain accuracy when no SRC is needed
    
    // Public for test harness
    @objc dynamic var frameLength: AVAudioFramePosition = 0 {
        willSet { willChangeValue( forKey: "duration" ); }
        didSet  { didChangeValue( forKey: "duration"); }
    }
    
    // If playback is scheduled, it will be enqueud as to play in the very near future
    // whilst the engine is running. For offline rendering, this should be set to false.
    private func play( atFrame frame: AVAudioFramePosition = 0, schedule: Bool = true )
    {
        if tracks.count == 0 { return; }
        
        lastPlayStart = frame;
        
        self.stop();

        for file in files
        {
            let track = trackFor( file: file )!;
            
            var startFrame = frame;
            
            let timelineFileLength = file.length( atSampleRate: audioFormat.sampleRate );
            
            if timelineFileLength <= startFrame
            {
                if track.loop
                {
                    startFrame = startFrame % timelineFileLength;
                }
                else
                {
                    // If we're not looping and we're past the end, we have nothing to do.
                    continue;
                }
            }
            
            // This block is used to loop any looped files
            func rescheduler( _ : AVAudioPlayerNodeCompletionCallbackType )
            {
                // Check nothing has changed since we started
                if !playing || !track.loop { return; }
                
                track.player.scheduleFile(
                    file, at: nil,
                    completionCallbackType: .dataConsumed, completionHandler: rescheduler
                );
            };
            
            let fileStartFrame = file.equivalent( positionTo: startFrame, atSampleRate: audioFormat.sampleRate )

            // We use at: nil, as we will user play( at: ) later.
            track.player.scheduleSegment(
                file,
                startingFrame: fileStartFrame,
                frameCount: AUAudioFrameCount( file.length - fileStartFrame ),
                at: nil,
                completionCallbackType: .dataConsumed, completionHandler: track.loop ? rescheduler : nil
            )
            
            track.player.prepare( withFrameCount: AVAudioFrameCount( audioFormat.sampleRate) );
        }
        
        // We shedule slightly later than now to allow pre-processing to happen,
        // then we don't run the risk of any players starting late. After the first
        // playback, then lastRenderTime will give us something meaningfull.

        let scheduleOffset = AVAudioFramePosition( audioFormat.sampleRate * 0.1 );
        let scheduleTime = ( tracks[0].player.lastRenderTime?.sampleTime ?? 0 ) + scheduleOffset;
        
        for track in tracks
        {
            if schedule
            {
                track.player.play( at: AVAudioTime( sampleTime: scheduleTime, atRate: audioFormat.sampleRate ) );
            }
            else
            {
                track.player.play();
            }
        }
        
        playing = true;
    }
    
    private func applyMuteState()
    {
        // We handle solo and mute independently, this avoids having to track the selected mute state, vs the
        // inherent mute state due to another track being solod.
        // In the current implementation is that there is no var on a track to flect a 'muted due to solo'
        // state in a UI. This could easly be added here though if desired.
        
        let haveSolo = tracks.reduce( false ) { ( prev, track ) in return prev || track.solo };
        if haveSolo
        {
            for track in tracks
            {
                track.muteMixer.outputVolume = track.solo ? 1.0 : 0.0;
            }
        }
        else
        {
            for track in tracks
            {
                track.muteMixer.outputVolume = track.mute ? 0.0 : 1.0;
            }
        }
    }
    
    // Use KVO to track mix changes made to vars on our track objects
    
    private func addObservers( track: Track )
    {
        track.addObserver( self, forKeyPath: "mute", options: .new, context: nil );
        track.addObserver( self, forKeyPath: "solo", options: .new, context: nil );
        track.addObserver( self, forKeyPath: "volume", options: .new, context: nil );
        track.addObserver( self, forKeyPath: "pan", options: .new, context: nil );
        track.addObserver( self, forKeyPath: "loop", options: .new, context: nil );
    }
    
    private func removeObservers( track: Track )
    {
        track.removeObserver( self, forKeyPath: "mute" );
        track.removeObserver( self, forKeyPath: "solo" );
        track.removeObserver( self, forKeyPath: "volume" );
        track.removeObserver( self, forKeyPath: "pan" );
        track.removeObserver( self, forKeyPath: "loop" );
    }
    
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?
    )
    {
        if object as? Track != nil
        {
            mixDirty = true;
            if keyPath == "mute" || keyPath == "solo"
            {
                applyMuteState();
            }
        }
    }
}
