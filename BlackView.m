//
//  BlackView.m
//  Isolator
//
//  Created by Ben Willmore on 08/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#include "Cocoa/Cocoa.h"
#import "BlackView.h"

@implementation BlackView

-(id) initWithFrame:(NSRect)frameRect
{	
	[super initWithFrame:(NSRect)frameRect];

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:@"BackgroundColor"]) {
		NSData *theData=[NSArchiver archivedDataWithRootObject:[NSColor blackColor]];
		[[NSUserDefaults standardUserDefaults] setObject:theData forKey:@"BackgroundColor"];
	}

	[self setColor];
	
	return self;
}

-(void) drawRect:(NSRect)theRect
{
	[bgColor set];
	NSRectFill(theRect);
}

-(void) setColor
{
	if (bgColor)
		[bgColor release];

	NSData *theData=[[NSUserDefaults standardUserDefaults] dataForKey:@"BackgroundColor"];
	if (theData)
		bgColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
	else
		bgColor = [NSColor blackColor];

	[bgColor retain];

	[self setNeedsDisplay:YES];
}

-(void) dealloc
{
	[bgColor release];
	[super dealloc];
}

@end
