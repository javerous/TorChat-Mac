/*
 *  TCChatTranscriptViewController.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
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

#import <WebKit/WebKit.h>

#import "TCChatTranscriptViewController.h"

#import "NSImage+TCExtension.h"
#import "NSString+TCXMLExtension.h"


/*
** Defines
*/
#pragma mark - Defines

#define TCTemplateCSSSnippet			@"CSS-Snippet"

#define TCTemplateRemoteMessageSnippet	@"RemoteMessage-Snippet"
#define TCTemplateLocalMessageSnippet	@"LocalMessage-Snippet"

#define TCTemplateErrorSnippet			@"Error-Snippet"
#define TCTemplateStatusSnippet			@"Status-Snippet"



/*
** Globals
*/
#pragma mark - Globals

dispatch_queue_t	gAvatarQueue;
NSMutableDictionary	*gAvatarCache;



/*
** TCURLProtocolInternal - Interface
*/
#pragma mark - TCURLProtocolInternal - Interface

@interface TCURLProtocolInternal : NSURLProtocol

+ (void)setAvatar:(NSImage *)avatar forIdentifier:(NSString *)identifier;
+ (void)removeAvatarForIdentifier:(NSString *)identifier;

@end



/*
** TCChatTranscriptViewController - Private
*/
#pragma mark - TCChatTranscriptViewController - Private

@interface TCChatTranscriptViewController () <WebUIDelegate, WebFrameLoadDelegate>
{
	WebView			*_webView;
	NSDictionary	*_template;
	
	NSString		*_localAvatarIdentifier;
	NSString		*_remoteAvatarIdentifier;
	
	BOOL			_isViewReady;

	NSString		*_tmpStyle;
	NSMutableString	*_tmpBody;
	
	int32_t			_messagesCount;
}

@end



/*
** TCChatTranscriptViewController
*/
#pragma mark - TCChatTranscriptViewController

@implementation TCChatTranscriptViewController


/*
** TCChatTranscriptViewController - Instance
*/
#pragma mark - TCChatTranscriptViewController - Instance

- (id)init
{
    self = [super init];
	
    if (self)
	{
		// Register internal protocol.
		static dispatch_once_t onceToken;
		
		dispatch_once(&onceToken, ^{
			[NSURLProtocol registerClass:[TCURLProtocolInternal class]];
		});

		// Init identifier.
		_localAvatarIdentifier = [self uuid];
		_remoteAvatarIdentifier	= [self uuid];
		
		[TCURLProtocolInternal setAvatar:[NSImage imageNamed:NSImageNameUser] forIdentifier:_localAvatarIdentifier];
		[TCURLProtocolInternal setAvatar:[NSImage imageNamed:NSImageNameUser] forIdentifier:_remoteAvatarIdentifier];

		// Load template.
		NSString	*path = [[NSBundle mainBundle] pathForResource:@"ChatTemplate" ofType:@"plist"];
		NSData		*data = [NSData dataWithContentsOfFile:path];
		
		_template = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
		
		// Temporary HTML section.
		_tmpBody = [[NSMutableString alloc] init];
		
		[self _reloadStyle];
	}
	
    return self;
}

- (void)dealloc
{
    [TCURLProtocolInternal removeAvatarForIdentifier:_localAvatarIdentifier];
	[TCURLProtocolInternal removeAvatarForIdentifier:_remoteAvatarIdentifier];
}



/*
** TCChatTranscriptViewController - NSViewController
*/
#pragma mark - TCChatTranscriptViewController - NSViewController

- (void)loadView
{
	// Build WebView.
	_webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, 50, 50)];
	
	[_webView setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	[_webView setUIDelegate:self];
	[_webView setFrameLoadDelegate:self];
	[_webView setDrawsBackground:YES];

	// Load empty HTML structure.
	NSString *html = [NSString stringWithFormat:@"<html><head><style></style></head><body></body></html>"];
	
	[[_webView mainFrame] loadHTMLString:html baseURL:nil];
	
	// Hold a the controlled view.
	self.view = _webView;
}



/*
** TCChatTranscriptViewController - WebView
*/
#pragma mark - TCChatTranscriptViewController - WebView

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    return nil;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	NSView *documentView = sender.mainFrame.frameView.documentView;
	
	// Activate elasticity.
	NSScrollView *scrollView = documentView.enclosingScrollView;
	
	[scrollView setVerticalScrollElasticity:NSScrollElasticityAllowed];
    [scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
		
	// Stuck document at end.
	[documentView setPostsFrameChangedNotifications:YES];
	
	[[NSNotificationCenter defaultCenter] addObserverForName:NSViewFrameDidChangeNotification
													  object:documentView
													   queue:nil
												  usingBlock:^(NSNotification *notification) {
													 
													  NSRect	docFrame = documentView.frame;
													  NSPoint	docPoint = NSMakePoint(docFrame.origin.x, docFrame.origin.y + docFrame.size.height);
													  													  
													  [documentView scrollPoint:docPoint];
												  }];
	
	// Set pending content.
	[[self _styleNode] setInnerHTML:_tmpStyle];
	[[self _bodyNode] setInnerHTML:_tmpBody];

	_isViewReady = YES;

	_tmpBody = nil;
	_tmpStyle = nil;
}



/*
** TCChatTranscriptViewController - Content
*/
#pragma mark - TCChatTranscriptViewController - Content

- (void)appendLocalMessage:(NSString *)message
{
	NSString *snippet = _template[TCTemplateLocalMessageSnippet];
	
	message = [message stringByEscapingXMLEntities];
	snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
	
	[self appendText:snippet];
	
	OSAtomicIncrement32(&_messagesCount);
}

- (void)appendRemoteMessage:(NSString *)message
{
	NSString *snippet = _template[TCTemplateRemoteMessageSnippet];

	message = [message stringByEscapingXMLEntities];
	snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
	
	[self appendText:snippet];
	
	OSAtomicIncrement32(&_messagesCount);
}

- (void)appendError:(NSString *)error
{
	NSString *snippet = _template[TCTemplateErrorSnippet];
	
	error = [error stringByEscapingXMLEntities];
	snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:error];
	
	[self appendText:snippet];
}

- (void)appendStatus:(NSString *)status
{
	NSString *snippet = _template[TCTemplateStatusSnippet];
	
	status = [status stringByEscapingXMLEntities];
	snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:status];
	
	[self appendText:snippet];
}

- (void)setLocalAvatar:(NSImage *)image
{
	if (!image)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[TCURLProtocolInternal removeAvatarForIdentifier:_localAvatarIdentifier];

		_localAvatarIdentifier = [self uuid];
		
		[TCURLProtocolInternal setAvatar:image forIdentifier:_localAvatarIdentifier];
		
		[self _reloadStyle];
	});
}

- (void)setRemoteAvatar:(NSImage *)image
{
	if (!image)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[TCURLProtocolInternal removeAvatarForIdentifier:_remoteAvatarIdentifier];
		
		_remoteAvatarIdentifier = [self uuid];
		
		[TCURLProtocolInternal setAvatar:image forIdentifier:_remoteAvatarIdentifier];
		
		[self _reloadStyle];
	});
}

- (NSUInteger)messagesCount
{
	return (NSUInteger)OSAtomicAdd32(0, &_messagesCount);
}



/*
** TCChatTranscriptViewController - Helpers
*/
#pragma mark - TCChatTranscriptViewController - Helpers

- (void)appendText:(NSString *)text
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self _appendBodyTag:@"div" innerHTML:text];
	});
}

- (void)_reloadStyle
{
	// > main queue <
	
	NSString *cssSnippet = _template[TCTemplateCSSSnippet];
	
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-RIGHT-BALLOON]" withString:@"tc-resource://balloon/right-balloon"];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LEFT-BALLOON]" withString:@"tc-resource://balloon/left-balloon"];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-REMOTE-AVATAR]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _remoteAvatarIdentifier]];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LOCAL-AVATAR]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _localAvatarIdentifier]];

	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-RIGHT-BALLOON-2X]" withString:@"tc-resource://balloon/right-balloon-2x"];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LEFT-BALLOON-2X]" withString:@"tc-resource://balloon/left-balloon-2x"];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-REMOTE-AVATAR-2X]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _remoteAvatarIdentifier]];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LOCAL-AVATAR-2X]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _localAvatarIdentifier]];
	
	[self _setStyle:cssSnippet];
}

- (void)_setStyle:(NSString *)style
{
	// > main queue <

	if ([style length] == 0)
		return;
	
	if (_isViewReady)
	{
		// Search style node.
		DOMHTMLElement *styleNode = [self _styleNode];
		
		[styleNode setInnerHTML:style];
		
		// Set need display.
		[_webView setNeedsDisplay:YES];
	}
	else
	{
		_tmpStyle = style;
	}
}

- (void)_appendBodyTag:(NSString *)tagName innerHTML:(NSString *)innerHTML
{
	// > main queue <
	
	// Create a new node.
	if (_isViewReady)
	{
		DOMDocument		*document = [[_webView mainFrame] DOMDocument];
		DOMHTMLElement	*newNode = (DOMHTMLElement *)[document createElement:tagName];
	
		[newNode setInnerHTML:innerHTML];
		[document.body appendChild:newNode];
	
		[_webView setNeedsDisplay:YES];
	}
	else
	{
		NSString *item = [NSString stringWithFormat:@"<%@>%@</%@>", tagName, innerHTML, tagName];
		
		[_tmpBody appendString:item];
	}
}

- (DOMHTMLElement *)_styleNode
{
	// > main queue <

	DOMDocument *document = [[_webView mainFrame] DOMDocument];
	
	// Search head.
	DOMNodeList		*headList = [document getElementsByTagName:@"head"];
	DOMHTMLElement	*headNode;
	
	if ([headList length] == 0)
		return nil;
	
	headNode = (DOMHTMLElement *)[headList item:0];
	
	// Search style.
	DOMNodeList *styleList = [headNode getElementsByTagName:@"style"];
	
	if ([styleList length] == 0)
		return nil;
	
	// Return style node.
	return (DOMHTMLElement *)[styleList item:0];
}

- (DOMHTMLElement *)_bodyNode
{
	// > main queue <

	DOMDocument *document = [[_webView mainFrame] DOMDocument];

	return document.body;
}

- (NSString *)uuid
{
	uuid_t			uuid;
	uuid_string_t	uuidStr;
	
	uuid_generate(uuid);
	uuid_unparse(uuid, uuidStr);
	
	return @(uuidStr);
}

@end




/*
** TCURLProtocolInternal
*/
#pragma mark - TCURLProtocolInternal

@implementation TCURLProtocolInternal


/*
** TCURLProtocolInternal - Instance
*/
#pragma mark - TCURLProtocolInternal - Instance

+ (void)initialize
{
	gAvatarQueue = dispatch_queue_create("com.torchat.app.url-protocol-internal.local", DISPATCH_QUEUE_CONCURRENT);
	gAvatarCache = [[NSMutableDictionary alloc] init];
}



/*
** TCURLProtocolInternal - Values
*/
#pragma mark - TCURLProtocolInternal - Values

+ (void)setAvatar:(NSImage *)avatar forIdentifier:(NSString *)identifier
{
	if (!avatar || !identifier)
		return;
	
	NSData *tiff = [avatar TIFFRepresentation];
	
	if (!tiff)
		return;
	
	dispatch_barrier_async(gAvatarQueue, ^{
		gAvatarCache[identifier] = tiff;
	});
}

+ (void)removeAvatarForIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	dispatch_barrier_async(gAvatarQueue, ^{
		[gAvatarCache removeObjectForKey:identifier];
	});
}



/*
** TCURLProtocolInternal - NSURLProtocol
*/
#pragma mark - TCURLProtocolInternal - NSURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)aRequest
{
    return ([aRequest.URL.scheme caseInsensitiveCompare:@"tc-resource"] == NSOrderedSame);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)aRequest
{
    return aRequest;
}

- (void)startLoading
{
	NSURL		*url = self.request.URL;
	NSString	*host = url.host;
		
	if ([host isEqualToString:@"avatar"])
		[self handleAvatar];
	else if ([host isEqualToString:@"balloon"])
		[self handleBalloon];
	else
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Unknown host" code:0 userInfo:@{}]];
}

- (void)stopLoading
{
}



/*
** TCURLProtocolInternal - Handlers
*/
#pragma mark - TCURLProtocolInternal - Handlers

- (void)handleAvatar
{
	// Get parameters.
	NSURL		*url = self.request.URL;
	NSArray		*parameters = url.pathComponents;
	NSString	*identifier = nil;

	if ([parameters count] < 2)
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Parameter error" code:0 userInfo:@{}]];
		return;
	}
	
	identifier = parameters[1];
	
	// Send avatar.
	dispatch_async(gAvatarQueue, ^{
		
		NSData *data = gAvatarCache[identifier];
		
		if (data)
		{
			// Build response.
			NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:@"image/tiff" expectedContentLength:(NSInteger)[data length] textEncodingName:nil];
			
			// Send response + content.
			[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
			[self.client URLProtocol:self didLoadData:data];
			[self.client URLProtocolDidFinishLoading:self];
		}
		else
		{
			[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Avatar not found" code:0 userInfo:@{}]];
		}
	});
}

- (void)handleBalloon
{
	// Get parameters.
	NSURL		*url = self.request.URL;
	NSArray		*parameters = url.pathComponents;
	NSString	*side = nil;
	
	if ([parameters count] < 2)
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Parameter error" code:0 userInfo:@{}]];
		return;
	}
	
	side = parameters[1];
	
	// Load image.
	static NSImage			*leftBalloon = nil;
	static NSImage			*rightBalloon = nil;
	static dispatch_once_t	onceToken;
	
	dispatch_once(&onceToken, ^{
		leftBalloon = [NSImage imageNamed:@"balloon_graphite"];
		rightBalloon = [[NSImage imageNamed:@"balloon_aqua"] flipHorizontally];
	});
	
	
    NSData *data = nil;
	NSRect targetRect = NSZeroRect;
	NSImage	*sourceImage = nil;
		
	if ([side isEqualToString:@"left-balloon"])
	{
		NSSize size = leftBalloon.size;
		
		targetRect = NSMakeRect(0, 0, size.width, size.height);
		sourceImage = leftBalloon;
	}
	else if ([side isEqualToString:@"right-balloon"])
	{
		NSSize size = rightBalloon.size;
		
		targetRect = NSMakeRect(0, 0, size.width, size.height);
		sourceImage = rightBalloon;
	}
	else if ([side isEqualToString:@"left-balloon-2x"])
	{
		NSSize size = leftBalloon.size;
		
		targetRect = NSMakeRect(0, 0, size.width * 2.0, size.height * 2.0);
		sourceImage = leftBalloon;
	}
	else if ([side isEqualToString:@"right-balloon-2x"])
	{
		NSSize size = rightBalloon.size;
		
		targetRect = NSMakeRect(0, 0, size.width * 2.0, size.height * 2.0);
		sourceImage = rightBalloon;
	}
	
	if (sourceImage)
	{
		NSImage *image = [NSImage imageWithSize:targetRect.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
			[sourceImage drawInRect:targetRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
			return YES;
		}];
		
		data = [image TIFFRepresentation];
	}
	
	if (!data)
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Can't create avatar" code:0 userInfo:@{}]];
		return;
	}
	
	// Build response.
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:@"image/tiff" expectedContentLength:(NSInteger)[data length] textEncodingName:nil];
	
	// Send response + content.
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [[self client] URLProtocol:self didLoadData:data];
    [[self client] URLProtocolDidFinishLoading:self];
}

@end
