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
#import <WebKit/WebKit.h>

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

	
	NSString *path = [@"~/Desktop/ballon_%u.tiff" stringByExpandingTildeInPath];
	
	[[img TIFFRepresentation] writeToFile:[NSString stringWithFormat:path, gIndex++]  atomically:NO];
}


WebView * search_webview(NSView *view)
{
	if ([view isKindOfClass:[WebView class]])
		return (WebView *)view;

	NSArray *subviews = [view subviews];
	
	for (NSView *subview in subviews)
	{
		WebView *result = search_webview(subview);
		
		if (result)
			return result;
	}
	
	return nil;
}

void save_view(NSView *view, NSUInteger *counter, NSString *path)
{
	// Save view content.
	NSSize size = view.frame.size;
	
	if (size.width != 0 && size.height != 0)
	{
		NSImage *image = [[NSImage alloc] initWithSize:size];
		
		[image lockFocus];
		{
			[view drawRect:NSMakeRect(0, 0, size.width, size.height)];
		}
		[image unlockFocus];
		
		*counter = *counter + 1;
		
		[[image TIFFRepresentation] writeToFile:[NSString stringWithFormat:path, *counter] atomically:NO];
	}

		
	// Recurse on subviews.
	NSArray *subviews = [view subviews];
	
	for (NSView *subview in subviews)
		save_view(subview, counter, path);
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
	
	
	static dispatch_source_t	timer;
	
	// Create dispatch source timer used to throttle saves to disk.
	timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	
	dispatch_source_set_event_handler(timer, ^{
		
		
		// Save all views content.
		{
			NSLog(@"Saving views...");

			static NSUInteger directoryIndex = 0;
			
			directoryIndex++;
			
			// > Create output directory.
			NSString	*path = [NSString stringWithFormat:[@"~/Desktop/ouput_%u" stringByExpandingTildeInPath], directoryIndex];
			NSString	*finalPath = [path stringByAppendingPathComponent:@"file_%lu.tiff"];

			[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
			
			// > Recurse on views.
			NSUInteger	counter = 0;
			NSArray		*windows = [[NSApplication sharedApplication] windows];

			for (NSWindow *window in windows)
				save_view([window contentView], &counter, finalPath);
		}
		
		
		/*
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			
			NSLog(@"Get image");
			NSURLRequest	*request;
			NSData			*data;

			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/16704303"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/16704303"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/13869566"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/13869566"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/7911934"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/7911934"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];

			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/16549578"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/16549578"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/16163624"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/16163624"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/11857483"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/11857483"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/11320007"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/11320007"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			// ---
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon-2x/14935011"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_2x_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
			
			request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"ichat-balloon-style://left-balloon/14935011"]];
			data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			[data writeToFile:[NSString stringWithFormat:[@"~/Desktop/balloon_trans_%u.tiff" stringByExpandingTildeInPath], archIndex++] atomically:NO];
		});
		*/
		
		/*
		{
			static unsigned archIndex = 0;

			NSLog(@"Archiving WebViews...");
			// Note: because of a bug in WebKit, image loaded from CSS with an URL are not always saved in the archive.
			
			// Get windows list
			NSArray *windows = [[NSApplication sharedApplication] windows];
			
			for (NSWindow *window in windows)
			{
				WebView *webView = search_webview([window contentView]);
				
				if (!webView)
					continue;
				
				DOMDocument *document = [[webView mainFrame] DOMDocument];
				WebArchive	*archive = [document webArchive];
				NSData		*page = [archive data];
				NSString	*path = [@"~/Desktop/transcript_%u.webarchive" stringByExpandingTildeInPath];
				
				[page writeToFile:[NSString stringWithFormat:path, archIndex++] atomically:NO];
			}
		}
		 */
	});
	
	dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 5ull * NSEC_PER_SEC, 0ull);
	dispatch_resume(timer);
}



