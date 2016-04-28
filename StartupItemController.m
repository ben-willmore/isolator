//
//  StartupItemController.m
//  Isolator
//
//  Created by Ben Willmore on 12/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "StartupItemController.h"

@implementation StartupItemController

-(id) init
{
	[super init];
	
	return self;
}

-(int) getIdx:(NSArray*)itemArray
{
	// see if our bundle identifier is present in the startupitems array
	// return index if so (starting at zero) or -1 if not
	
	int idx = -1;
	
	NSEnumerator* enumerator = [itemArray objectEnumerator];
	
	NSDictionary* item;
	NSURL* url;
	NSString* path;
	NSBundle* bundle;
	NSString* bundleID;
	
	int thisIdx = 0;
	while( (item = [enumerator nextObject]) && (idx==-1) ) {
		url = [item objectForKey:@"URL"];
		path = [url path];
		if (path) {
			bundle = [NSBundle bundleWithPath:path];
			if (bundle) {
				bundleID = [bundle bundleIdentifier];
				if ([bundleID isEqual:[[NSBundle mainBundle] bundleIdentifier]])
					idx = thisIdx;
			}
		}
		thisIdx++;
	}
	return idx;
}

-(BOOL) enabled
{
	// return YES if number of startup items with our bundle identifier is >0
	
	OSStatus err;
	NSArray* itemArray = NULL;
	int idx = -1;

	err = LIAECopyLoginItems((CFArrayRef*)&itemArray);
	
	if (err != noErr)
		return NO;
	
	idx = [self getIdx:itemArray];
	[itemArray release];
	
	if (idx>=0)
		return YES;
	else
		return NO;

}

-(void) setEnabled:(BOOL)value
{
	// remove all existing startup items with our bundle identifier, and then
	// add one new one if value==YES
	
	if ([self enabled])
		[self removeStartupItem];
	
	if (value)
		[self addStartupItem];
}


-(void) removeStartupItem
{
	// remove all existing startup items with our bundle identifier
	
	OSStatus err;
	NSArray* itemArray = NULL;
	
	int idx = 0;

	while (idx>=0) {
		err = LIAECopyLoginItems((CFArrayRef*)&itemArray);
	
		if (err != noErr)
			return;
	
		idx = [self getIdx:itemArray];

		[itemArray release];
		itemArray = NULL;
		if (idx>=0)
			LIAERemove(idx);
	}
}

-(void) addStartupItem
{
	// add startup item
	NSURL * theURL = [[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]] retain];
	if ([theURL isEqual:nil])
		NSLog(@"Isolator: Attempted to add nil path to loginitems");
	else
		LIAEAddURLAtEnd((CFURLRef)theURL, NO);
	[theURL release];
}
		
@end
