//
//  LessThanAboutOne.m
//  Isolator
//
//  Created by Ben Willmore on 13/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "LessThanAboutOne.h"

const float kSlop = 0.02;

@implementation LessThanAboutOne

+ (Class)transformedValueClass;
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation;
{
    return NO;   
}

- (id)transformedValue:(id)value;
{
	if ([value compare:[NSNumber numberWithFloat:(1.0-kSlop)]]==NSOrderedAscending)
		return [NSNumber numberWithBool:YES];
	else
		return [NSNumber numberWithBool:NO];
}

@end
