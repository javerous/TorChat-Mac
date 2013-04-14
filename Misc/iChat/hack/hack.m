/*
 *  hack.m
 *
 *  Copyright 2012 Avérous Julien-Pierre
 *
 *  This file is part of TorChat.
 *
 *  TorChat is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  TorChat is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with TorChat.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <Cocoa/Cocoa.h>

#include <objc/message.h>


static unsigned gIndex = 0;

/*
//- (id)initByReferencingFile:(NSString *)filename;
static id (*original_NSImage_initByReferencingFile)(NSImage* self, SEL _cmd, NSString *filename);

id replaced_NSImage_initByReferencingFile(NSImage* self, SEL _cmd, NSString *filename)
{
	NSLog(@"[NSImage initByReferencingFile:'%@']", filename);
	
	if (filename)
		[[NSFileManager defaultManager] copyItemAtPath:filename toPath:[@"/Users/jp/Desktop/output/" stringByAppendingPathComponent:[filename lastPathComponent]] error:nil];
	
	return original_NSImage_initByReferencingFile(self, _cmd, filename);
}

//- (id)initByReferencingURL:(NSURL *)url;
static id (*original_NSImage_initByReferencingURL)(NSImage* self, SEL _cmd, NSURL *url);

id replaced_NSImage_initByReferencingURL(NSImage* self, SEL _cmd, NSURL *url)
{
	NSLog(@"[NSImage initByReferencingURL:'%@']", [url path]);
	
	if (url)
		[[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:[@"/Users/jp/Desktop/output/" stringByAppendingPathComponent:[[url path] lastPathComponent]] error:nil];
	
	return original_NSImage_initByReferencingURL(self, _cmd, url);
}

//- (id)initWithContentsOfFile:(NSString *)filename;
static id (*original_NSImage_initWithContentsOfFile)(NSImage* self, SEL _cmd, NSString *filename);

id replaced_NSImage_initWithContentsOfFile(NSImage* self, SEL _cmd, NSString *filename)
{
	NSLog(@"[NSImage initWithContentsOfFile:'%@']", filename);
	
	if (filename)
		[[NSFileManager defaultManager] copyItemAtPath:filename toPath:[@"/Users/jp/Desktop/output/" stringByAppendingPathComponent:[filename lastPathComponent]] error:nil];
	
	return original_NSImage_initWithContentsOfFile(self, _cmd, filename);
}

//- (id)initWithContentsOfURL:(NSURL *)aURL;
static id (*original_NSImage_initWithContentsOfURL)(NSImage* self, SEL _cmd, NSURL *aURL);

id replaced_NSImage_initWithContentsOfURL(NSImage* self, SEL _cmd, NSURL *aURL)
{
	NSLog(@"[NSImage initWithContentsOfURL:'%@']", [aURL path]);
	
	if (aURL)
		[[NSFileManager defaultManager] copyItemAtPath:[aURL path] toPath:[@"/Users/jp/Desktop/output/" stringByAppendingPathComponent:[[aURL path] lastPathComponent]] error:nil];
	
	return original_NSImage_initWithContentsOfURL(self, _cmd, aURL);
}

//- (id)initWithData:(NSData *)data;
static id (*original_NSImage_initWithData)(NSImage* self, SEL _cmd, NSData *data);

id replaced_NSImage_initWithData(NSImage* self, SEL _cmd, NSData *data)
{
	NSLog(@"[NSImage initWithData:%ld]", [data length]);
	
	if (data)
		[data writeToFile:[NSString stringWithFormat:@"/Users/jp/Desktop/output/raw_%u", gIndex++] atomically:NO];
	
	return original_NSImage_initWithData(self, _cmd, data);
}

//+ (id)imageNamed:(NSString *)name;
static id (*original_NSImage_imageNamed)(NSImage* self, SEL _cmd, NSString *name);

id replaced_NSImage_imageNamed(NSImage* self, SEL _cmd, NSString *name)
{
	NSLog(@"[NSImage imageNamed:'%@']", name);
	
	NSImage *img = original_NSImage_imageNamed(self, _cmd, name);
	
	if (img)
		[[img TIFFRepresentation] writeToFile:[NSString stringWithFormat:@"/Users/jp/Desktop/output/%@_%u", name, gIndex++] atomically:NO];
	
	return img;
}
*/

//- (void)drawBalloonInRect:(struct CGRect)arg1 tailAtPoint:(struct CGPoint)arg2 withShadow:(id)arg3 fillColor:(id)arg4 strokeColor:(id)arg5 lineWidth:(float)arg6 curve:(float)arg7;
static void (*original_drawBalloonInRect)(NSView *self, SEL _cmd, struct CGRect in_rect, struct CGPoint tail_at_point, id shadow, id fill_color, id stroke_color, float line_width, float curve);

void replace_drawBalloonInRect(NSView *self, SEL _cmd, struct CGRect in_rect, struct CGPoint tail_at_point, id shadow, id fill_color, id stroke_color, float line_width, float curve)
{
	NSLog(@"Draw Ballon");

	// Draw for iChat
	original_drawBalloonInRect(self, _cmd, in_rect, tail_at_point, shadow, fill_color, stroke_color, line_width, curve);

	
	// Draw for copy
	NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(in_rect.origin.x + in_rect.size.width + 50, in_rect.origin.y + in_rect.size.height + 50)];
	
	[img lockFocusFlipped:YES];
	{
		original_drawBalloonInRect(self, _cmd, in_rect, tail_at_point, shadow, fill_color, stroke_color, line_width, curve);
	}
	[img unlockFocus];

	[[img TIFFRepresentation] writeToFile:[NSString stringWithFormat:@"/Users/jp/Desktop/output/ballon_%u.tiff", gIndex++]  atomically:NO];
}



 void __attribute__ ((constructor)) my_init(void)
{
	NSLog(@"*** Hack Welcome ***");

	/*
	 // NSImage
	 Method NSImage_initByReferencingFile = class_getInstanceMethod([NSImage class], @selector(initByReferencingFile:));
	 Method NSImage_initByReferencingURL = class_getInstanceMethod([NSImage class], @selector(initByReferencingURL:));
	 Method NSImage_initWithContentsOfFile = class_getInstanceMethod([NSImage class], @selector(initWithContentsOfFile:));
	 Method NSImage_initWithContentsOfURL = class_getInstanceMethod([NSImage class], @selector(initWithContentsOfURL:));
	 Method NSImage_initWithData = class_getInstanceMethod([NSImage class], @selector(initWithData:));
	 Method NSImage_imageNamed = class_getInstanceMethod([NSImage class], @selector(imageNamed:));
	 
	 original_NSImage_initByReferencingFile = (void *)method_setImplementation(NSImage_initByReferencingFile, (IMP)replaced_NSImage_initByReferencingFile);
	 original_NSImage_initByReferencingURL = (void *)method_setImplementation(NSImage_initByReferencingURL, (IMP)replaced_NSImage_initByReferencingURL);
	 original_NSImage_initWithContentsOfFile = (void *)method_setImplementation(NSImage_initWithContentsOfFile, (IMP)replaced_NSImage_initWithContentsOfFile);
	 original_NSImage_initWithContentsOfURL = (void *)method_setImplementation(NSImage_initWithContentsOfURL, (IMP)replaced_NSImage_initWithContentsOfURL);
	 original_NSImage_initWithData = (void *)method_setImplementation(NSImage_initWithData, (IMP)replaced_NSImage_initWithData);
	 original_NSImage_imageNamed = (void *)method_setImplementation(NSImage_imageNamed, (IMP)replaced_NSImage_imageNamed);
	 */

	// iChat
	Method _drawBalloonInRect = class_getInstanceMethod([NSView class], @selector(drawBalloonInRect:tailAtPoint:withShadow:fillColor:strokeColor:lineWidth:curve:));

	original_drawBalloonInRect = (void *)method_setImplementation(_drawBalloonInRect, (IMP)replace_drawBalloonInRect);
}
