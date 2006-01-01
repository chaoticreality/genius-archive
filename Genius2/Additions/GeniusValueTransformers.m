//
//  GeniusValueTransformers.m
//  Genius2
//
//  Created by John R Chang on 2005-09-26.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GeniusValueTransformers.h"


@implementation GeniusFloatPercentTransformer

+ (Class) transformedValueClass
{
	return [NSNumber self];
}

+ (BOOL) allowsReverseTransformation
{
	return NO;
}

- (id) transformedValue:(id)value
{
	if (value == nil)
		return nil;
	float x = [value floatValue];
	x *= 100.0;
	return [NSNumber numberWithFloat:x];
}

@end


/*@implementation GeniusImageStringTransformer

+ (Class) transformedValueClass
{
	return [NSString self];
}

+ (BOOL) allowsReverseTransformation
{
	return YES;
}

- (id) transformedValue:(id)value
{
	if (value == nil)
		return nil;
	
	unichar ch = 0xFFFC;	// Unicode object replacement character
	NSString * objectReplacementString = [NSString stringWithCharacters:&ch length:1];

	NSMutableString * tmpString = [value mutableCopy];
	NSString * imagePlaceholderString = NSLocalizedString(@"[Image]", nil);

	[tmpString replaceOccurrencesOfString:objectReplacementString withString:imagePlaceholderString options:nil range:NSMakeRange(0, [tmpString length])];
	return [tmpString autorelease];
}

@end*/


@implementation GeniusEnabledBooleanToTextColorTransformer

+ (Class) transformedValueClass
{
	return [NSColor self];
}

+ (BOOL) allowsReverseTransformation
{
	return NO;
}

- (id) transformedValue:(id)value
{
	if (value == nil)
		return nil;
	
	return ([value boolValue] ? [NSColor blackColor] : [NSColor grayColor]);
}

@end


@implementation GeniusBooleanToStringTransformer

+ (Class) transformedValueClass
{
	return [NSString self];
}

+ (BOOL) allowsReverseTransformation
{
	return NO;
}

- (id) transformedValue:(id)value
{
	if (value == nil)
		return nil;
	
	return ([value boolValue] ? NSLocalizedString(@"YES", nil) : NSLocalizedString(@"NO", nil));
}

@end
