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

#import "TCWaveformView.h"


@implementation TCWaveformView
{
	bool _displayAsLoop;
}

@synthesize verticalScale, pointData, numPoints, waveformColor, waveformLoopColor, backgroundColor;


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
      [self initView];
    }
    return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
      [self initView];
    }
    return self;
}


- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self setNeedsDisplay:true];
}


- (void) initView
{
    self.pointData = NULL;
    self.numPoints = 0;
    
    self.verticalScale = 1.0f;
  
    self.backgroundColor = [NSColor whiteColor];
    self.waveformColor = [NSColor grayColor];
	self.waveformLoopColor = [[NSColor grayColor] colorWithAlphaComponent:0.4];
	
	self.displayAsLoop = false;
}


- (void)setSampleData:(float *)sampleData numSamples:(unsigned int)numSamples scale:(float)scale
{
	if ( self.pointData )
	{
		free( self.pointData );
	}
	
	if (  !sampleData || numSamples == 0 )
	{
		self.pointData = NULL;
		self.numPoints = 0;
        [self setNeedsDisplay:true];
		return;
	}

	self.pointData = (CGPoint *)calloc(sizeof(CGPoint),numSamples);
	for ( unsigned int i=0; i<numSamples; i++ )
	{
		self.pointData[i] = CGPointMake( i, sampleData[i] );
	}
  
	self.numPoints = numSamples;
    self.scale = scale;
	
	[self setNeedsDisplay:true];
}

- (void) normalize
{
	if (!self.pointData) { return; }
	
	CGFloat maxVal = 0.0f;
	for (unsigned int i = 0; i < numPoints; ++i) {
		maxVal = MAX(self.pointData[i].y, maxVal);
	}
	
	if( maxVal > 0 ) {
		verticalScale = 1 / maxVal;
	}
	
	[self setNeedsDisplay: true];
}

- (void)setDisplayAsLoop:(bool)loops
{
	_displayAsLoop = loops;
	[self setNeedsDisplay:true];
}

- (bool)displayAsLoop{ return _displayAsLoop; }

- (void)drawRect:(CGRect)rect
{
	
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	
	if( self.opaque )
	{
		CGContextSetFillColorWithColor(context, self.backgroundColor.CGColor);
		CGContextFillRect(context, self.bounds);
	}
	
	if ( !self.pointData || self.numPoints == 0 ) { return; }
	
	// I'm sure there is a nice way to refactor this, and be a little more
	// modular, but I'm sleepy.
	
	// Work out x/y scale to normalize our data in the view frame (with a user
	// scale override)
	CGFloat xScale = (float)self.bounds.size.width / ((float)self.numPoints - 1) * self.scale;
	CGFloat yScale = self.bounds.size.height * self.verticalScale;
	
	// Offset by xScale as the waveform data points are the 'middle' not the left edge
	CGAffineTransform lowerXform = CGAffineTransformMake( 1, 0, 0, 1, xScale/2, rect.size.height/2);
	lowerXform = CGAffineTransformScale( lowerXform, xScale, yScale/2 );
	CGAffineTransform upperXform = CGAffineTransformMake( 1, 0, 0, -1, xScale/2, rect.size.height/2 );
	upperXform = CGAffineTransformScale( upperXform, xScale, yScale/2 );
	
	const CGPoint *data = self.pointData;
	const unsigned long nPoints = self.numPoints;
	
	// Draw the waveform that represents the samples themselves
	
	CGMutablePathRef waveformPath = CGPathCreateMutable();
	
	CGPathMoveToPoint(waveformPath, &lowerXform, 0.0f, 0.0f);
	CGPathAddLineToPoint(waveformPath, &lowerXform, 0.0f, data[0].y);
	for (unsigned long i = 0; i < nPoints; i++)
	{
		CGPathAddLineToPoint(waveformPath, &lowerXform, data[i].x, data[i].y);
	}
	
	for (long i = nPoints-1; i >= 0; --i)
	{
		CGPathAddLineToPoint(waveformPath, &upperXform, data[i].x, data[i].y);
	}
	CGPathAddLineToPoint(waveformPath, &upperXform, 0.0f, 0.0f);
	
	[self.waveformColor setFill];
	CGContextAddPath(context, waveformPath);
	CGContextFillPath(context);
	
	// If we're in loop mode - draw repeats to fill the view if we've been
	// scaled down such that the samples are less than the full width.
	
	const int numCopies = ceil(1.0f / self.scale) - 1;
	if( self.displayAsLoop && numCopies > 0) {
		
		CGMutablePathRef copiesPath = CGPathCreateMutable();

		CGFloat copyOriginX = self.numPoints;
		
		CGPathMoveToPoint(copiesPath, &lowerXform, copyOriginX, 0.0f);
		
		// Draw the top half n times
		for( unsigned int c = 1; c <= numCopies; ++c ) {
			CGPathAddLineToPoint(copiesPath, &lowerXform, copyOriginX, data[0].y);
			for (unsigned long i = 0; i < nPoints; i++)
			{
				CGPathAddLineToPoint(copiesPath, &lowerXform, copyOriginX + data[i].x, data[i].y);
			}
			copyOriginX += self.numPoints;
		}
		
		// Come back from the far end and draw the bottom half
		for( unsigned int c = numCopies; c >= 1; --c ) {
			copyOriginX -= self.numPoints;
			for (long i = nPoints-1; i >= 0; --i)
			{
				CGPathAddLineToPoint(copiesPath, &upperXform, copyOriginX + data[i].x, data[i].y);
			}
		}
		
		CGPathAddLineToPoint(copiesPath, &upperXform, copyOriginX, 0.0f);
		
		[self.waveformLoopColor setFill];
		CGContextAddPath(context, copiesPath);
		CGContextFillPath(context);
		
		CGPathRelease( copiesPath );
	}
    
	CGPathRelease( waveformPath );
}


@end
