//
//  Copyright (c) 2013, Tom Cowland. All rights reserved.
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

#import "TCWaveformDataSource.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/ExtendedAudioFile.h>

@interface TCWaveformDataSource (Private)

- (BOOL)configureReaderFor:(ExtAudioFileRef *)audioRef withResultingFormat:(AudioStreamBasicDescription *)dataFormat;
- (Float32)buildPacketOfSize:(UInt32)packetSize audioRef:(ExtAudioFileRef *)audioRef withBuffer:(AudioBufferList *)audioBufferList;

- (Float32 *)getDecimatedSamples:(UInt32)packetSize outNumPackets:(UInt32 *)numPackets outPointLength:(float *)pointLength;
- (Float32 *)getDecimatedSamplesFromCache:(UInt32)packetSize outNumPackets:(UInt32 *)numPackets outPointLength:(float *)pointLength;

@end



@implementation TCWaveformDataSource
{
    Float32 *_decimationCache;
    UInt32 _decimationCachePacketSize;
    UInt32 _decimationCachePacketCount;
	float _decimationCachePacketLength;
	SInt64 _fileLengthInFrames;
	Float64 _fileSampleRate;
}


@synthesize audioFile;

// TODO: clear things when the audio file is changed

- (id)init
{
    self = [super init];
    if ( self )
    {
		_decimationCache = NULL;
		_decimationCachePacketSize = 0;
		_fileLengthInFrames = 0;
		[self clearDecimationCache];
    }
    return self;
}



-(void)clearDecimationCache
{
    if ( _decimationCache )
    {
      free( _decimationCache );
    }
  
    _decimationCache = NULL;
    _decimationCachePacketCount = 0;
    _decimationCachePacketSize = 0;
}



- (void)preDecimate:(UInt32)packetSize
{
  if ( packetSize == _decimationCachePacketSize ) { return; }
 
	UInt32 cachePacketCount = 0;
	float cachePacketLengh = 0;
	
	float *sampleData = [self getDecimatedSamples:packetSize outNumPackets:&cachePacketCount outPointLength:&cachePacketLengh];
	
	if ( _decimationCache )
    {
		free( _decimationCache );
    }
    _decimationCache = sampleData;
	
	_decimationCachePacketCount = cachePacketCount;
	_decimationCachePacketLength = cachePacketLengh;
	_decimationCachePacketSize = packetSize;
}



- (Float32 *)getSampleData:(UInt32)packetSize storingNumDataPointsIn:(UInt32 *)numPoints pointLength:(float *)pointLength
{
  if ( ! _decimationCachePacketCount || packetSize < _decimationCachePacketSize )
  {
	  return [self getDecimatedSamples:packetSize outNumPackets:numPoints outPointLength:pointLength];
  }
  else
  {
	  return [self getDecimatedSamplesFromCache:packetSize outNumPackets:numPoints outPointLength:pointLength];
  }
}

- (Float32 *)getSampleDataWithMaxPoints:(UInt32)maxPoints storingNumDataPointsIn:(UInt32 *)numPoints pointLength:(float *)pointLength
{
	UInt32 targetPacketSize = 1;
	
	if ( _decimationCachePacketCount > 0 )
	{
		targetPacketSize = ( _decimationCachePacketSize * _decimationCachePacketCount ) / maxPoints;
	}
	else
	{
		if ( _fileLengthInFrames == 0 )
		{
			ExtAudioFileRef audioRef = NULL;
			OSStatus error = ExtAudioFileOpenURL((__bridge CFURLRef)(self.audioFile), &audioRef);
		
			if ( error ) {
				NSLog(@"Unable to open audio file: %d", (int)error);
				ExtAudioFileDispose( audioRef ); return NULL;
			}
		
			AudioStreamBasicDescription dataFormat;
			if( ! [self configureReaderFor:&audioRef withResultingFormat:&dataFormat] ){
				ExtAudioFileDispose( audioRef ); return NULL;
			}
		
		
			UInt32 thePropertySize = sizeof(_fileLengthInFrames);
			error = ExtAudioFileGetProperty(audioRef, kExtAudioFileProperty_FileLengthFrames, &thePropertySize, &_fileLengthInFrames);
			if ( error ) {
				NSLog(@"Unable to open audio file: %d", (int)error);
				ExtAudioFileDispose( audioRef ); return NULL;
			}
		}
		
		targetPacketSize = (UInt32)(_fileLengthInFrames / maxPoints);
	}
	
	
	return [self getSampleData:targetPacketSize storingNumDataPointsIn:numPoints pointLength:pointLength];

}



- (Float32 *)getDecimatedSamplesFromCache:(UInt32)packetSize outNumPackets:(UInt32 *)numPackets outPointLength:(float *)pointLength
{
    if ( ! self.audioFile ) { return NULL; }
  
    if ( packetSize <= _decimationCachePacketSize )
    {
		size_t cacheSize = _decimationCachePacketCount * sizeof(Float32);

		Float32 *cacheCopy;
		cacheCopy = (Float32 *)malloc( cacheSize );
		memcpy( cacheCopy, _decimationCache, cacheSize );

		(*pointLength) = _decimationCachePacketSize / _fileSampleRate;
		(*numPackets) = _decimationCachePacketCount;

		return cacheCopy;
    }
    else
    {
        UInt32 adjustedPackedSize = packetSize / _decimationCachePacketSize;
        (*numPackets) = ceil( (double)_decimationCachePacketCount / (double)adjustedPackedSize );
		
		UInt32 actualPacketSize = adjustedPackedSize * _decimationCachePacketSize;
		(*pointLength) = actualPacketSize / _fileSampleRate;
      
        Float32 *decimated;
        decimated = (Float32 *)malloc( (*numPackets) * sizeof(Float32) );
      
        Float32 packetValue;
      
        UInt32 cacheIndex = 0;
        Float32 *currentDataPoint = decimated;
        for ( UInt32 i=0; i<(*numPackets); i++ )
        {
          packetValue = 0.0f;
        
          for ( UInt32 j=0; j<adjustedPackedSize; j++ )
          {
            if ( cacheIndex >= _decimationCachePacketCount )
            {
              break;
            }
            
            packetValue = MAX(packetValue, _decimationCache[cacheIndex]);
            ++cacheIndex;
          }
          
          (*currentDataPoint) = packetValue;
          ++currentDataPoint;
        }
      
        return decimated;
    }
}


- (Float32 *)getDecimatedSamples:(UInt32)packetSize  outNumPackets:(UInt32 *)numPackets outPointLength:(float *)pointLength
{
    if ( ! self.audioFile ) { return NULL; }
  
    OSStatus error = noErr;
  
    ExtAudioFileRef audioRef = NULL;
    error = ExtAudioFileOpenURL((__bridge CFURLRef)(self.audioFile), &audioRef);
  
    if ( error ) {
      NSLog(@"Unable to open audio file: %d", (int)error);
      ExtAudioFileDispose( audioRef ); return NULL;
    }
  
    AudioStreamBasicDescription dataFormat;
    if( ! [self configureReaderFor:&audioRef withResultingFormat:&dataFormat] ){
      ExtAudioFileDispose( audioRef ); return NULL;
    }

    _fileLengthInFrames = 0;

    UInt32 thePropertySize = sizeof(_fileLengthInFrames);
    error = ExtAudioFileGetProperty(audioRef, kExtAudioFileProperty_FileLengthFrames, &thePropertySize, &_fileLengthInFrames);
    if ( error ) {
      NSLog(@"Unable to open audio file: %d", (int)error);
      ExtAudioFileDispose( audioRef ); return NULL;
    }
	
	
	AudioStreamBasicDescription sourceFormat;
	UInt32 sourceDataSize = sizeof(sourceFormat);
	ExtAudioFileGetProperty(audioRef, kExtAudioFileProperty_FileDataFormat, &sourceDataSize, &sourceFormat);
	
  
    UInt32 dataSize = packetSize * dataFormat.mBytesPerFrame;
    void *dataBuffer = malloc(dataSize);
    if ( ! dataBuffer ) {
      NSLog(@"Unable to allocate memory for reading :(");
      ExtAudioFileDispose( audioRef ); return NULL;
    }
  
    AudioBufferList audioBuffer;
		audioBuffer.mNumberBuffers = 1;
		audioBuffer.mBuffers[0].mDataByteSize = dataSize;
		audioBuffer.mBuffers[0].mNumberChannels = dataFormat.mChannelsPerFrame;
		audioBuffer.mBuffers[0].mData = dataBuffer;
  
    (*numPackets) = ceil( (double)_fileLengthInFrames / (double)packetSize );
    Float32 *packets;
    packets = (Float32 *)malloc( (*numPackets) * sizeof(Float32) );
	if( !packets )
	{
      NSLog(@"Unable to allocate memory for packet data :(");
      ExtAudioFileDispose( audioRef ); return NULL;
	}
	
    for ( UInt64 i=0; i<(*numPackets); i++ )
    {
      packets[i] = [self buildPacketOfSize:packetSize audioRef:&audioRef withBuffer:&audioBuffer];
    }

	_fileSampleRate = sourceFormat.mSampleRate;
	(*pointLength) = packetSize / _fileSampleRate;

	ExtAudioFileDispose( audioRef );
    return packets;
}



- (BOOL)configureReaderFor:(ExtAudioFileRef *)ref withResultingFormat:(AudioStreamBasicDescription *)dataFormat
{

    OSStatus error = noErr;
  
    AudioStreamBasicDescription fileFormat;
    UInt32 formatDataSize = sizeof(fileFormat);

    error = ExtAudioFileGetProperty( *ref, kExtAudioFileProperty_FileDataFormat, &formatDataSize, &fileFormat);
  
    if ( error ) {
      NSLog(@"Unable to retrieve audio file properties: %d", (int)error);
      return FALSE;
    }

    memset( dataFormat, 0, sizeof(AudioStreamBasicDescription) );
  
    dataFormat->mFormatID = kAudioFormatLinearPCM;

    dataFormat->mSampleRate = fileFormat.mSampleRate;
    dataFormat->mChannelsPerFrame = fileFormat.mChannelsPerFrame;

    dataFormat->mFramesPerPacket = 1;
    dataFormat->mBitsPerChannel = sizeof(Float32) * 8;
    dataFormat->mBytesPerFrame = dataFormat->mChannelsPerFrame * sizeof(Float32);
    dataFormat->mBytesPerPacket = dataFormat->mChannelsPerFrame * sizeof(Float32);
    dataFormat->mFormatFlags = kAudioFormatFlagIsFloat;

    error = ExtAudioFileSetProperty( *ref, kExtAudioFileProperty_ClientDataFormat, formatDataSize, dataFormat);
  
    if ( error ) {
      NSLog(@"Unable to set client audio data properties: %d", (int)error);
      return FALSE;
    }
  
    return TRUE;
}


- (Float32)buildPacketOfSize:(UInt32)packetSize audioRef:(ExtAudioFileRef *)audioRef withBuffer:(AudioBufferList *)audioBufferList
{
    OSStatus error = noErr;
  
    UInt32 readPackets = packetSize;

   // Process the data in chunks based on our packet size
		error = ExtAudioFileRead( *audioRef, &readPackets, audioBufferList );
    if( error ) { return 0.0f; }
  
    UInt32 numChannels = audioBufferList->mBuffers[0].mNumberChannels;
    Float32 *data = audioBufferList->mBuffers[0].mData;
  
    Float32 packetValue = 0.0f;
    Float32 frameValue;
  
    for( size_t i=0; i<readPackets; i++ )
    {
      frameValue = 0.0f;
      
      for ( size_t j=0; j<numChannels; j++ )
      {
		  frameValue = MAX(frameValue, fabsf( *data ));
        ++data;
      }
    
      packetValue = MAX(packetValue, frameValue);
    }
 
    return packetValue;
}



@end
