//
//  TextColourForBool.m
//  Isolator
//
//  Created by Ben Willmore on 13/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TextColourForBool.h"

@implementation TextColourForBool

+ (Class)transformedValueClass;
{
    return [NSColor class];
}

+ (BOOL)allowsReverseTransformation;
{
    return NO;   
}

- (id)transformedValue:(id)value;
{
	if ([value boolValue])
		return [NSColor blackColor];
	else
		return [NSColor grayColor];
}

@end
