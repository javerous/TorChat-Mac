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

#import "TCChatMessage.h"


/*
** Defines
*/
#pragma mark - Defines

#define TCTemplateCSSSnippet				@"CSS-Snippet"

#define TCTemplateRemoteMessageSnippet		@"RemoteMessage-Snippet"
#define TCTemplateLocalMessageSnippet		@"LocalMessage-Snippet"
#define TCTemplateLocalMessageErrorSnippet	@"LocalMessageError-Snippet"

#define TCTemplateStatusSnippet				@"Status-Snippet"

#define TCTemplateMinHeight					@"Min-Height"



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

@interface TCChatTranscriptViewController () <WebUIDelegate, WebFrameLoadDelegate, WebPolicyDelegate>
{
	WebView			*_webView;
	NSDictionary	*_template;
	
	NSString		*_localAvatarIdentifier;
	NSString		*_remoteAvatarIdentifier;
	
	BOOL			_isViewReady;

	NSString		*_tmpStyle;
	NSMutableString	*_tmpBody;
	
	int32_t			_messagesCount;
	
	NSMutableIndexSet *_handledMessagesIDs;
	
	DOMHTMLElement	*_anchorElement;
	CGFloat			_anchorOffset;
	
	BOOL			_stuckAtEnd;
	
	id <NSObject>	_frameChangeObserver;
	id <NSObject>	_didScrollObserver;
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
		
		// Init flags.
		_stuckAtEnd = YES;
		
		// Init identifier.
		_localAvatarIdentifier = [self uuid];
		_remoteAvatarIdentifier	= [self uuid];
		
		[TCURLProtocolInternal setAvatar:[NSImage imageNamed:NSImageNameUser] forIdentifier:_localAvatarIdentifier];
		[TCURLProtocolInternal setAvatar:[NSImage imageNamed:NSImageNameUser] forIdentifier:_remoteAvatarIdentifier];

		// Containers.
		_handledMessagesIDs = [[NSMutableIndexSet alloc] init];
		
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
	TCDebugLog(@"TCChatTranscriptViewController dealloc");
	
    [TCURLProtocolInternal removeAvatarForIdentifier:_localAvatarIdentifier];
	[TCURLProtocolInternal removeAvatarForIdentifier:_remoteAvatarIdentifier];
	
	[[NSNotificationCenter defaultCenter] removeObserver:_frameChangeObserver];
	[[NSNotificationCenter defaultCenter] removeObserver:_didScrollObserver];
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
	[_webView setPolicyDelegate:self];
	
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
		
	// Stuck scroll position.
	__weak TCChatTranscriptViewController *weakSelf = self;
	
	[documentView setPostsFrameChangedNotifications:YES];
	
	_frameChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSViewFrameDidChangeNotification object:documentView queue:nil usingBlock:^(NSNotification *notification) {
		
		TCChatTranscriptViewController *strongSelf = weakSelf;
		
		if (!strongSelf)
			return;
		
		NSRect	docFrame = documentView.frame;
		NSRect	docVisibleFrame = scrollView.documentVisibleRect;

		if (strongSelf->_stuckAtEnd)
			[documentView scrollPoint:NSMakePoint(docFrame.origin.x, docFrame.size.height)];
		else
			[documentView scrollPoint:NSMakePoint(docFrame.origin.x, strongSelf->_anchorElement.offsetTop - (strongSelf->_anchorOffset + docVisibleFrame.size.height))];
	}];
	
	_didScrollObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSScrollViewDidLiveScrollNotification object:scrollView queue:nil usingBlock:^(NSNotification *notification) {
		
		TCChatTranscriptViewController *strongSelf = weakSelf;
		
		if (!strongSelf)
			return;
		
		// Compute stuck offset by using invisible html anchor position.
		NSRect	docFrame = documentView.frame;
		NSRect	docVisibleFrame = scrollView.documentVisibleRect;

		strongSelf->_anchorOffset = strongSelf->_anchorElement.offsetTop - (docVisibleFrame.size.height + docVisibleFrame.origin.y);
		strongSelf->_stuckAtEnd = ((docVisibleFrame.origin.y + docVisibleFrame.size.height) >= docFrame.size.height);
		
		// Notify.
		void (^transcriptScrollHandler)(TCChatTranscriptViewController *controller, CGFloat scrollOffset) = strongSelf.transcriptScrollHandler;
		
		if (transcriptScrollHandler)
			transcriptScrollHandler(strongSelf, docVisibleFrame.origin.y);
	}];
	
	// Set pending content.
	[[self _styleNode] setInnerHTML:_tmpStyle];
	[[self _bodyNode] setInnerHTML:_tmpBody];

	_isViewReady = YES;

	_tmpBody = nil;
	_tmpStyle = nil;
	
	// Add invisible anchor node.
	DOMDocument *document = [[_webView mainFrame] DOMDocument];
	
	_anchorElement = (DOMHTMLElement *)[document createElement:@"div"];

	[document.body appendChild:_anchorElement];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	NSURL *url = request.URL;
	
	if ([url.scheme isEqualToString:@"tc-action"])
	{
		// Get type.
		NSString *type = url.host;
		
		if ([type isEqualToString:@"error"])
		{
			// Get path.
			NSString	*path = [url.path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
			NSArray		*components = [path componentsSeparatedByString:@"/"];
			
			if (components.count == 0)
			{
				[listener use];
				return;
			}

			// Handle error action.
			void (^errorActionHandler)(TCChatTranscriptViewController *controller, int64_t messageID) = self.errorActionHandler;
			
			if (errorActionHandler)
			{
				NSString	*msgIDStr = components[0];
				int64_t		msgID = strtoll(msgIDStr.UTF8String, NULL, 10);
				
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					errorActionHandler(self, msgID);
				});
			}
			
			// Ignore action.
			[listener ignore];
			return;
		}
	}
	
	[listener use];
}



/*
** TCChatTranscriptViewController - Content
*/
#pragma mark - TCChatTranscriptViewController - Content

- (void)addMessages:(NSArray *)messages endOfTranscript:(BOOL)endOfTranscript
{
	NSMutableArray *items = [[NSMutableArray alloc] init];
	
	// Convert message.
	[messages enumerateObjectsUsingBlock:^(TCChatMessage * _Nonnull msg, NSUInteger idx, BOOL * _Nonnull stop) {
		
		if (msg.messageID < 0)
			return;
		
		// Prevent duplication.
		if ([_handledMessagesIDs containsIndex:(NSUInteger)msg.messageID])
			return;
		
		[_handledMessagesIDs addIndex:(NSUInteger)msg.messageID];
		
		// Convert message.
		switch (msg.side)
		{
			case TCChatMessageSideLocal:
			{
				if (msg.error)
				{
					NSString *snippet = _template[TCTemplateLocalMessageErrorSnippet];
					NSString *message = msg.message;
					
					message = [message stringByEscapingXMLEntities];
					snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
					snippet = [snippet stringByReplacingOccurrencesOfString:@"[HREF-ERROR]" withString:[NSString stringWithFormat:@"tc-action://error/%llu", msg.messageID]];
					
					[items addObject:@{ @"id" : @(msg.messageID), @"html" : snippet }];
				}
				else
				{
					NSString *snippet = _template[TCTemplateLocalMessageSnippet];
					NSString *message = msg.message;

					message = [message stringByEscapingXMLEntities];
					snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
					
					[items addObject:@{ @"id" : @(msg.messageID), @"html" : snippet }];
				}
				
				OSAtomicIncrement32(&_messagesCount);
				
				break;
			}

			case TCChatMessageSideRemote:
			{
				NSString *snippet = _template[TCTemplateRemoteMessageSnippet];
				NSString *message = msg.message;

				message = [message stringByEscapingXMLEntities];
				snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
				
				[items addObject:@{ @"html" : snippet }];
				
				OSAtomicIncrement32(&_messagesCount);
				
				break;
			}
		}
	}];
	
	// Add messages to transcript.
	[self addItems:items endOfTranscript:endOfTranscript];
}

- (void)removeMessageID:(int64_t)msgID
{
	[self removeItemID:msgID];
}

- (void)appendStatus:(NSString *)status
{
	NSString *snippet = _template[TCTemplateStatusSnippet];
	
	status = [status stringByEscapingXMLEntities];
	snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:status];
	
	[self addItems:@[ @{ @"html" : snippet } ] endOfTranscript:YES];
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

- (CGFloat)scrollOffset
{
	NSView			*documentView = _webView.mainFrame.frameView.documentView;
	NSScrollView	*scrollView = documentView.enclosingScrollView;
	
	return scrollView.documentVisibleRect.origin.y;
}



/*
** TCChatTranscriptViewController - Helpers
*/
#pragma mark - TCChatTranscriptViewController - Helpers

#pragma mark Computation

- (NSUInteger)messagesCountToFillHeight:(CGFloat)height
{
	NSNumber *minHeight = _template[TCTemplateMinHeight];
	
	if (!minHeight)
		return 0;
	
	return (NSUInteger)ceil(height / [minHeight doubleValue]);
}

- (CGFloat)heightForMessagesCount:(NSUInteger)count
{
	NSNumber *minHeight = _template[TCTemplateMinHeight];
	
	if (!minHeight)
		return 0;
	
	return (CGFloat)count * [minHeight doubleValue];
}



#pragma mark Items

- (void)addItems:(NSArray *)items endOfTranscript:(BOOL)endOfTranscript
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Create a new node.
		if (_isViewReady)
		{
			DOMDocument *document = [[_webView mainFrame] DOMDocument];
			DOMNode		*firstChild = document.body.firstChild;
			
			for (NSDictionary *item in items)
			{
				NSString *html = item[@"html"];
				NSNumber *divID = item[@"id"];
				
				DOMHTMLElement *newNode = (DOMHTMLElement *)[document createElement:@"div"];
				
				if (divID)
					[newNode setAttribute:@"id" value:[NSString stringWithFormat:@"item_%lld", [divID longLongValue]]];
				
				[newNode setInnerHTML:html];
				
				if (endOfTranscript)
					[document.body appendChild:newNode];
				else
					[document.body insertBefore:newNode refChild:firstChild];
			}

			[_webView setNeedsDisplay:YES];
		}
		else
		{
			NSMutableString *bunch = [[NSMutableString alloc] init];
			
			for (NSDictionary *item in items)
			{
				NSString *html = item[@"html"];
				NSNumber *divID = item[@"id"];
				
				if (divID)
					[bunch appendFormat:@"<div id=\"item_%lld\">%@</div>", [divID longLongValue], html];
				else
					[bunch appendFormat:@"<div>%@</div>", html];
			}
			
			if (endOfTranscript)
				[_tmpBody appendString:bunch];
			else
				[_tmpBody insertString:bunch atIndex:0];
		}
	});
}

- (void)removeItemID:(int64_t)itemID
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		DOMDocument			*document = [[_webView mainFrame] DOMDocument];
		NSString			*expression = [NSString stringWithFormat:@"/html/body/div[@id='item_%lld']", itemID];
		DOMXPathExpression  *xPath = [document createExpression:expression resolver:nil];
		DOMXPathResult		*result =  [xPath evaluate:document type:DOM_ANY_TYPE inResult:nil];
		DOMNode				*node = [result iterateNext];
		
		if (!node || [node isKindOfClass:[DOMHTMLElement class]] == NO)
			return;
		
		[document.body removeChild:node];
		
		[_webView setNeedsDisplay:YES];
		
		[_handledMessagesIDs removeIndex:(NSUInteger)itemID];
	});
}


#pragma mark Style

- (void)_reloadStyle
{
	// > main queue <
	
	NSString *cssSnippet = _template[TCTemplateCSSSnippet];
	
	// 1x
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-RIGHT-BALLOON]" withString:@"tc-resource://balloon/right-balloon"];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LEFT-BALLOON]" withString:@"tc-resource://balloon/left-balloon"];
	
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-REMOTE-AVATAR]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _remoteAvatarIdentifier]];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LOCAL-AVATAR]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _localAvatarIdentifier]];
	
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-ERROR-BUTTON]" withString:@"tc-resource://error/button"];

	
	// 2x
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-RIGHT-BALLOON-2X]" withString:@"tc-resource://balloon/right-balloon-2x"];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LEFT-BALLOON-2X]" withString:@"tc-resource://balloon/left-balloon-2x"];
	
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-REMOTE-AVATAR-2X]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _remoteAvatarIdentifier]];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LOCAL-AVATAR-2X]" withString:[NSString stringWithFormat:@"tc-resource://avatar/%@", _localAvatarIdentifier]];
	
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-ERROR-BUTTON-2X]" withString:@"tc-resource://error/button-2x"];

	
	[self _setStyle:cssSnippet];
}


#pragma mark DOM

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


#pragma mark UUID

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
	else if ([host isEqualToString:@"error"])
		[self handleError];
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

- (void)handleError
{
	// Get parameters.
	NSURL		*url = self.request.URL;
	NSArray		*parameters = url.pathComponents;
	NSString	*name = nil;
	
	if ([parameters count] < 2)
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Parameter error" code:0 userInfo:@{}]];
		return;
	}
	
	name = parameters[1];
	
	// Handle name.
	NSSize	targetSize = NSZeroSize;
	CGFloat	targetFontSize = 0;
	
	if ([name isEqualToString:@"button"])
	{
		targetSize = NSMakeSize(20, 20);
		targetFontSize = 14;
	}
	else if ([name isEqualToString:@"button-2x"])
	{
		targetSize = NSMakeSize(40, 40);
		targetFontSize = 28;
	}
	else
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"unknow error request" code:404 userInfo:@{}]];
		return;
	}
	
	// Create image.
	NSImage *image = [NSImage imageWithSize:NSMakeSize(targetSize.width, targetSize.height * 2.0) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		
		// > Snippet to draw different versions.
		void (^drawError)(NSColor *color, CGFloat position) = ^(NSColor *color, CGFloat yPosition) {
		
			NSDictionary *attributes = @{ NSFontAttributeName : [NSFont fontWithName:@"Georgia" size:targetFontSize], NSForegroundColorAttributeName : color };

			// > Circle
			NSRect			circleRect = NSInsetRect(NSMakeRect(0, yPosition, targetSize.width, targetSize.height), 1.0, 1.0);
			NSBezierPath	*circle = [NSBezierPath bezierPathWithOvalInRect:circleRect];
			
			circle.lineWidth = 0.5;
			
			[color set];
			[circle stroke];
			
			// > @"!"
			NSString	*exclamStr = @"!";
			NSSize		exclamSize = [exclamStr sizeWithAttributes:attributes];
			NSPoint		point;

			exclamSize.height -= exclamSize.height / 6.0;
			
			point.x = circleRect.origin.x + (circleRect.size.width - exclamSize.width) / 2.0;
			point.y = circleRect.origin.y + (circleRect.size.height - exclamSize.height) / 2.0;
			
			[exclamStr drawAtPoint:point withAttributes:attributes];
		};
		
		// Draw.
		CGFloat hue = 1.0;
		CGFloat saturation = 1.0;
		CGFloat brightness = 1.0;

		drawError([NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0], targetSize.height);
		drawError([NSColor colorWithHue:hue saturation:saturation brightness:brightness * 0.65 alpha:1.0], 0);

		return YES;
	}];
	
	NSData *data = [image TIFFRepresentation];
	
	// Build response.
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:@"image/tiff" expectedContentLength:(NSInteger)[data length] textEncodingName:nil];
	
	// Send response + content.
	[[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
	[[self client] URLProtocol:self didLoadData:data];
	[[self client] URLProtocolDidFinishLoading:self];
}

@end
