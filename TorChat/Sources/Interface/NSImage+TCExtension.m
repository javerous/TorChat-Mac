//
//  NSImage+TCExtension.m
//  TranscriptPtest
//
//  Created by Julien-Pierre Avérous on 11/12/2013.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "NSImage+TCExtension.h"


/*
** NSImage + TCExtension
*/
#pragma mark - NSImage + TCExtension

@implementation NSImage (TCExtension)

- (NSImage *)flipHorizontally
{
    NSSize	size = self.size;
    NSImage	*result = [[NSImage alloc] initWithSize:size];
	
    [result lockFocus];
	{
		NSAffineTransform *translate = [NSAffineTransform transform];
		
		[translate translateXBy:size.width yBy:0];
		[translate scaleXBy:-1 yBy:1];
		[translate concat];
		
		[self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
    [result unlockFocus];
	
    return result;
}

@end
