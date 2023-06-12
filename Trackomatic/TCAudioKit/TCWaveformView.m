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


@synthesize verticalScale, pointData, numPoints, waveformColor, backgroundColor, dropShadow;


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
    
    self.dropShadow = false;
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



- (void)drawRect:(CGRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
 
	if( self.opaque )
	{
		CGContextSetFillColorWithColor(context, self.backgroundColor.CGColor);
		CGContextFillRect(context, self.bounds);
	}
	
	if ( !self.pointData || self.numPoints == 0 ) { return; }
  
    CGFloat xScale = (float)self.bounds.size.width / ((float)self.numPoints - 1) * self.scale;
    CGFloat yScale = self.bounds.size.height * self.verticalScale;
  
	// Offset by xScale as the waveform data points are the 'middle' not the left edge
    CGAffineTransform lowerXform = CGAffineTransformMake( 1, 0, 0, 1, xScale/2, rect.size.height/2);
    lowerXform = CGAffineTransformScale( lowerXform, xScale, yScale/2 );

    CGAffineTransform upperXform = CGAffineTransformMake( 1, 0, 0, -1, xScale/2, rect.size.height/2 );
    upperXform = CGAffineTransformScale( upperXform, xScale, yScale/2 );
  

	const CGPoint *data = self.pointData;
	const unsigned long nPoints = self.numPoints;
	
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
	
	
	// Fill this path
	[self.waveformColor setFill];
	
	CGContextAddPath(context, waveformPath);
	CGContextFillPath(context);
	
    if( self.dropShadow ) {
        
    	// Now create a larger rectangle, which we're going to subtract the visible path from
    	// and apply a shadow
    	CGMutablePathRef path = CGPathCreateMutable();
    	CGPathAddRect(path, NULL, rect);
    	
    	// Add the visible path (so that it gets subtracted for the shadow)
    	CGPathAddPath(path, NULL, waveformPath);
    	CGPathCloseSubpath(path);
    	
    	// Add the visible paths as the clipping path to the context
    	CGContextAddPath(context, waveformPath);
    	CGContextClip(context);
    	
    	// Now setup the shadow properties on the context
    	NSColor *aColor = [NSColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f];
    	CGContextSaveGState(context);
    	CGContextSetShadowWithColor(context, CGSizeMake(1.0f, 1.0f), 2.0f, [aColor CGColor]);
    	
    	// Now fill the rectangle, so the shadow gets drawn
    	[self.backgroundColor setFill];
    	CGContextSaveGState(context);
    	CGContextAddPath(context, path);
    	CGContextEOFillPath(context);
	
    	CGPathRelease(path);
    }
    
	CGPathRelease( waveformPath );
}


@end
