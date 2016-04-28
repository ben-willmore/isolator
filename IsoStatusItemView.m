//
//  IsoStatusItemView.m
//  Isolator
//
//  Created by Ben Willmore on 06/03/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "IsoStatusItemView.h"
#include <AppKit/NSEvent.h>

#define NSAppKitVersionNumber10_4 824

@implementation IsoStatusItemView

- (id) initWithFrame:(NSRect)frame isoController:(IsoController*)theIsoController
{
	[super initWithFrame:frame];
	
	isoController = theIsoController;
	highlighted = NO;
	
	return self;
}

- (void) drawRect:(NSRect)bounds {
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	[[isoController getStatusItem] drawStatusBarBackgroundInRect:bounds withHighlight:highlighted];

	NSRect rect;
	NSColor * embossedColor = nil;
	NSColor * outerBorderColor = nil;
	NSColor * innerBorderColor = nil;
	NSColor * squareColor = nil;
	
	float width = 14.;
	float xborder = (bounds.size.width-width)/2;
	float height = 14.;
	float yborder = (bounds.size.height-height)/2;

	if (!highlighted) {
		if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4)
			embossedColor = [NSColor colorWithDeviceRed:240./255 green:240./255 blue:240./255 alpha:0.4];

		outerBorderColor = [NSColor blackColor];
		innerBorderColor = [NSColor colorWithDeviceRed:60./255 green:60./255 blue:60./255 alpha:0.7];
	}
	else {
		outerBorderColor = [NSColor whiteColor];
		innerBorderColor = [NSColor colorWithDeviceRed:200./255 green:200./255 blue:200./255 alpha:1.0];
	}
	
	if ([isoController isActive]) {
		NSData *theData=[defaults dataForKey:@"BackgroundColor"];
		if (theData) {
			squareColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
			if ([defaults objectForKey:@"BackgroundOpacity"])
				squareColor = [squareColor colorWithAlphaComponent:[defaults floatForKey:@"BackgroundOpacity"]];
		}
		else  // nothing stored for background colour
			squareColor = [NSColor blackColor];
	}
	else // inactive
		squareColor = nil;
		
	if (embossedColor) {
		[embossedColor set];
		//rect = NSMakeRect(bounds.origin.x+4,bounds.origin.y+3,bounds.size.width-8, bounds.size.height-9);
		rect = NSMakeRect(xborder, yborder-1, width, height-1);
		NSFrameRectWithWidth(rect,1);
	}
	
	[outerBorderColor set];
	//rect = NSMakeRect(bounds.origin.x+4,bounds.origin.y+4,bounds.size.width-8, bounds.size.height-8);
	rect = NSMakeRect(xborder, yborder, width, height);
	NSFrameRectWithWidth(rect,1);

	[innerBorderColor set];
	//rect = NSMakeRect(bounds.origin.x+5,bounds.origin.y+5,bounds.size.width-10, bounds.size.height-10);
	rect = NSMakeRect(xborder+1, yborder+1, width-2, height-2);
	NSFrameRectWithWidth(rect,1);
	
	if (squareColor) {
		[squareColor set];
		//rect = NSMakeRect(bounds.origin.x+6,bounds.origin.y+6,bounds.size.width-12, bounds.size.height-12);
		rect = NSMakeRect(xborder+2, yborder+2, width-4, height-4);
		NSRectFill(rect);
	}
}
	
- (void)mouseDown:(NSEvent *)event
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	//NSLog(@"%@",event);
	int mod = [event modifierFlags];
	if ( (mod&NSControlKeyMask) || ([defaults integerForKey:@"MouseClickEffect"]==1) ) {
		highlighted = YES;
		[self setNeedsDisplay:YES];
		[isoController showStatusMenu];
		highlighted = NO;
		[self setNeedsDisplay:YES];
	}
	else
		[isoController toggle];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	highlighted = YES;
	[self setNeedsDisplay:YES];file://localhost/Users/ben/projects/fun/Isolator/IsoController.m
	[isoController showStatusMenu];
	highlighted = NO;
	[self setNeedsDisplay:YES];
}

@end
