/*
 *  TCChatTranscriptViewController.m
 *
 *  Copyright 2019 Avérous Julien-Pierre
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

#import <stdatomic.h>

#import "TCChatTranscriptViewController.h"

#import "NSImage+TCExtension.h"
#import "NSString+TCXMLExtension.h"

#import "TCChatMessage.h"
#import "TCChatNotice.h"

#import "TCThemesManager.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Globals
*/
#pragma mark - Globals

dispatch_queue_t	gValuesQueue;
NSMutableDictionary	*gAvatarCache;
NSMutableDictionary	*gThemeCache;



/*
** TCURLProtocolInternal - Interface
*/
#pragma mark - TCURLProtocolInternal - Interface

@interface TCURLProtocolInternal : NSURLProtocol

+ (void)setTheme:(TCTheme *)theme forIdentifier:(NSString *)identifier;
+ (void)removeThemeForIdentifier:(NSString *)identifier;

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
	
	TCTheme			*_theme;
	NSString		*_themeIdentifier;
	
	NSString		*_localAvatarIdentifier;
	NSString		*_remoteAvatarIdentifier;
	
	BOOL			_isViewReady;

	NSString		*_tmpStyle;
	NSMutableString	*_tmpBody;
	
	atomic_uint_fast64_t _messagesCount;
	
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

- (instancetype)initWithTheme:(TCTheme *)theme
{
    self = [super initWithNibName:nil bundle:nil];
	
    if (self)
	{
		// Register internal protocol.
		static dispatch_once_t onceToken;
		
		dispatch_once(&onceToken, ^{
			[NSURLProtocol registerClass:[TCURLProtocolInternal class]];
		});
		
		// Hold theme.
		_theme = theme;
		_themeIdentifier = [self uuid];
		
		[TCURLProtocolInternal setTheme:theme forIdentifier:_themeIdentifier];
		
		// Init flags.
		_stuckAtEnd = YES;
		
		// Init identifier.
		_localAvatarIdentifier = [self uuid];
		_remoteAvatarIdentifier	= [self uuid];
		
		[TCURLProtocolInternal setAvatar:(NSImage *)[NSImage imageNamed:NSImageNameUser] forIdentifier:_localAvatarIdentifier];
		[TCURLProtocolInternal setAvatar:(NSImage *)[NSImage imageNamed:NSImageNameUser] forIdentifier:_remoteAvatarIdentifier];
		
		// Temporary HTML section.
		_tmpBody = [[NSMutableString alloc] init];
		
		[self _reloadStyle];
	}
	
    return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCChatTranscriptViewController dealloc");
	
	[TCURLProtocolInternal removeThemeForIdentifier:_themeIdentifier];
	
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
	
	_webView.UIDelegate = self;
	_webView.frameLoadDelegate = self;
	_webView.policyDelegate = self;
	
	[_webView setDrawsBackground:YES];

	// Load empty HTML structure.
	NSString *html = [NSString stringWithFormat:@"<html><head><style></style></head><body></body></html>"];
	
	[_webView.mainFrame loadHTMLString:html baseURL:nil];
	
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

- (NSUInteger)webView:(WebView *)webView dragSourceActionMaskForPoint:(NSPoint)point
{
	return WebDragSourceActionNone;
}

- (NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	return WebDragDestinationActionNone;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	NSView *documentView = sender.mainFrame.frameView.documentView;
	
	// Activate elasticity.
	NSScrollView *scrollView = documentView.enclosingScrollView;
	
	scrollView.verticalScrollElasticity = NSScrollElasticityAllowed;
    scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
		
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
	[self _styleNode].innerHTML = _tmpStyle;
	[self _bodyNode].innerHTML = _tmpBody;

	_isViewReady = YES;

	_tmpBody = nil;
	_tmpStyle = nil;
	
	// Add invisible anchor node.
	DOMDocument *document = _webView.mainFrame.DOMDocument;
	
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

- (void)addItems:(NSArray *)items endOfTranscript:(BOOL)endOfTranscript
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSMutableArray *result = [[NSMutableArray alloc] init];
		
		[items enumerateObjectsUsingBlock:^(id _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
			
			if ([item isKindOfClass:[TCChatMessage class]])
			{
				TCChatMessage *msg = item;
				
				switch (msg.side)
				{
					case TCChatMessageSideLocal:
					{
						if (msg.error)
						{
							NSString *snippet = _theme.chatTheme[TCThemeChatSnippetsKey][TCThemeChatSnippetLocalErrorKey];
							NSString *message = msg.message;
							
							message = message.escapedXMLEntities;
							snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
							snippet = [snippet stringByReplacingOccurrencesOfString:@"[HREF-ERROR]" withString:[NSString stringWithFormat:@"tc-action://error/%lld", msg.messageID]];
							snippet = [snippet stringByReplacingOccurrencesOfString:@"[URL-ERROR-BUTTON]" withString:@"tc-resource://error/button"];
							snippet = [snippet stringByReplacingOccurrencesOfString:@"[URL-THEME-ID]" withString:_themeIdentifier];

							[result addObject:@{ @"id" : @(msg.messageID), @"html" : snippet }];
						}
						else
						{
							NSString *snippet = _theme.chatTheme[TCThemeChatSnippetsKey][TCThemeChatSnippetLocalMessageKey];
							NSString *message = msg.message;
							
							message = message.escapedXMLEntities;
							snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
							snippet = [snippet stringByReplacingOccurrencesOfString:@"[URL-THEME-ID]" withString:_themeIdentifier];

							[result addObject:@{ @"id" : @(msg.messageID), @"html" : snippet }];
						}
						
						atomic_fetch_add(&_messagesCount, 1);
						
						break;
					}
						
					case TCChatMessageSideRemote:
					{
						NSString *snippet = _theme.chatTheme[TCThemeChatSnippetsKey][TCThemeChatSnippetRemoteMessageKey];
						NSString *message = msg.message;
						
						message = message.escapedXMLEntities;
						snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:message];
						
						[result addObject:@{ @"html" : snippet }];
						
						atomic_fetch_add(&_messagesCount, 1);
						
						break;
					}
				}
			}
			else if ([item isKindOfClass:[TCChatNotice class]])
			{
				TCChatNotice *stat = item;
				
				NSString *snippet = nil;
				
				switch (stat.type)
				{
					case TCChatNoticeTypeStandard:
						snippet = _theme.chatTheme[TCThemeChatSnippetsKey][TCThemeChatSnippetNoticeStdKey];
						break;
						
					case TCChatNoticeTypeError:
						snippet = _theme.chatTheme[TCThemeChatSnippetsKey][TCThemeChatSnippetNoticeErrorKey];
						break;
				}
				
				if (!snippet)
					return;
				
				// Set status content in snippet.
				snippet = [snippet stringByReplacingOccurrencesOfString:@"[TEXT]" withString:stat.content.escapedXMLEntities];
				
				// Add result.
				[result addObject:@{ @"html" : snippet }];
			}
		}];
		
		// Add items.
		[self _addItems:result endOfTranscript:endOfTranscript];
	});
}

- (void)removeMessageID:(int64_t)msgID
{
	[self removeItemID:msgID];
}

- (void)setLocalAvatar:(NSImage *)image
{
	NSAssert(image, @"image is nil");

	dispatch_async(dispatch_get_main_queue(), ^{
		
		[TCURLProtocolInternal removeAvatarForIdentifier:_localAvatarIdentifier];

		_localAvatarIdentifier = [self uuid];
		
		[TCURLProtocolInternal setAvatar:image forIdentifier:_localAvatarIdentifier];
		
		[self _reloadStyle];
	});
}

- (void)setRemoteAvatar:(NSImage *)image
{
	NSAssert(image, @"image is nil");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[TCURLProtocolInternal removeAvatarForIdentifier:_remoteAvatarIdentifier];
		
		_remoteAvatarIdentifier = [self uuid];
		
		[TCURLProtocolInternal setAvatar:image forIdentifier:_remoteAvatarIdentifier];
		
		[self _reloadStyle];
	});
}

- (NSUInteger)messagesCount
{
	return (NSUInteger)atomic_load(&_messagesCount);
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

- (NSUInteger)maxMessagesCountToFillHeight:(CGFloat)height
{
	NSNumber *minHeight = _theme.chatTheme[TCThemeChatPropertiesKey][TCThemeChatPropertyMinHeightKey];
	
	if (!minHeight)
		return 0;
	
	return (NSUInteger)ceil(height / minHeight.doubleValue);
}

- (CGFloat)maxHeightForMessagesCount:(NSUInteger)count
{
	NSNumber *minHeight = _theme.chatTheme[TCThemeChatPropertiesKey][TCThemeChatPropertyMinHeightKey];
	
	if (!minHeight)
		return 0;
	
	return (CGFloat)count * minHeight.doubleValue;
}



#pragma mark Items

- (void)_addItems:(NSArray *)items endOfTranscript:(BOOL)endOfTranscript
{
	// > main queue <
	
	// Create a new node.
	if (_isViewReady)
	{
		DOMDocument *document = _webView.mainFrame.DOMDocument;
		DOMNode		*firstChild = document.body.firstChild;
		
		for (NSDictionary *item in items)
		{
			NSString *html = item[@"html"];
			NSNumber *divID = item[@"id"];
			
			DOMHTMLElement *newNode = (DOMHTMLElement *)[document createElement:@"div"];
			
			if (divID)
				[newNode setAttribute:@"id" value:[NSString stringWithFormat:@"item_%lld", divID.longLongValue]];
			
			newNode.innerHTML = html;
			
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
				[bunch appendFormat:@"<div id=\"item_%lld\">%@</div>", divID.longLongValue, html];
			else
				[bunch appendFormat:@"<div>%@</div>", html];
		}
		
		if (endOfTranscript)
			[_tmpBody appendString:bunch];
		else
			[_tmpBody insertString:bunch atIndex:0];
	}
}

- (void)removeItemID:(int64_t)itemID
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		DOMDocument			*document = _webView.mainFrame.DOMDocument;
		NSString			*expression = [NSString stringWithFormat:@"/html/body/div[@id='item_%lld']", itemID];
		DOMXPathExpression  *xPath = [document createExpression:expression resolver:nil];
		DOMXPathResult		*result =  [xPath evaluate:document type:DOM_ANY_TYPE inResult:nil];
		DOMNode				*node = [result iterateNext];
		
		if (!node || [node isKindOfClass:[DOMHTMLElement class]] == NO)
			return;
		
		[document.body removeChild:node];
		
		[_webView setNeedsDisplay:YES];
	});
}


#pragma mark Style

- (void)_reloadStyle
{
	// > main queue <
	
	NSString *cssSnippet = _theme.chatTheme[TCThemeChatSnippetsKey][TCThemeChatSnippetCSSKey];
	
	// Global.
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-THEME-ID]" withString:_themeIdentifier];

	// Avatar.
	// > 1x
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-REMOTE-AVATAR]" withString:[NSString stringWithFormat:@"tc-resource://medias/avatar/1x/%@", _remoteAvatarIdentifier]];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LOCAL-AVATAR]" withString:[NSString stringWithFormat:@"tc-resource://medias/avatar/1x/%@", _localAvatarIdentifier]];
	
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-ERROR-BUTTON]" withString:@"tc-resource://medias/error/1x/button"];

	
	// > 2x
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-REMOTE-AVATAR-2X]" withString:[NSString stringWithFormat:@"tc-resource://medias/avatar/2x/%@", _remoteAvatarIdentifier]];
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-LOCAL-AVATAR-2X]" withString:[NSString stringWithFormat:@"tc-resource://medias/avatar/2x/%@", _localAvatarIdentifier]];
	
	cssSnippet = [cssSnippet stringByReplacingOccurrencesOfString:@"[URL-ERROR-BUTTON-2X]" withString:@"tc-resource://medias/error/2x/button"];

	[self _setStyle:cssSnippet];
}


#pragma mark DOM

- (void)_setStyle:(NSString *)style
{
	// > main queue <

	if (style.length == 0)
		return;
	
	if (_isViewReady)
	{
		// Search style node.
		DOMHTMLElement *styleNode = [self _styleNode];
		
		styleNode.innerHTML = style;
		
		// Set need display.
		[_webView setNeedsDisplay:YES];
	}
	else
	{
		_tmpStyle = style;
	}
}

- (nullable DOMHTMLElement *)_styleNode
{
	// > main queue <

	DOMDocument *document = _webView.mainFrame.DOMDocument;
	
	// Search head.
	DOMNodeList		*headList = [document getElementsByTagName:@"head"];
	DOMHTMLElement	*headNode;
	
	if (headList.length == 0)
		return nil;
	
	headNode = (DOMHTMLElement *)[headList item:0];
	
	// Search style.
	DOMNodeList *styleList = [headNode getElementsByTagName:@"style"];
	
	if (styleList.length == 0)
		return nil;
	
	// Return style node.
	return (DOMHTMLElement *)[styleList item:0];
}

- (DOMHTMLElement *)_bodyNode
{
	// > main queue <

	DOMDocument *document = _webView.mainFrame.DOMDocument;

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
	gValuesQueue = dispatch_queue_create("com.torchat.app.url-protocol-internal.local", DISPATCH_QUEUE_CONCURRENT);
	gAvatarCache = [[NSMutableDictionary alloc] init];
	gThemeCache = [[NSMutableDictionary alloc] init];
}



/*
** TCURLProtocolInternal - Values
*/
#pragma mark - TCURLProtocolInternal - Values

+ (void)setTheme:(TCTheme *)theme forIdentifier:(NSString *)identifier
{
	NSAssert(theme, @"theme is nil");
	NSAssert(identifier, @"identifier is nil");
	
	dispatch_barrier_async(gValuesQueue, ^{
		gThemeCache[identifier] = theme;
	});
}

+ (void)removeThemeForIdentifier:(NSString *)identifier
{
	NSAssert(identifier, @"identifier is nil");
	
	dispatch_barrier_async(gValuesQueue, ^{
		[gThemeCache removeObjectForKey:identifier];
	});
}

+ (void)setAvatar:(NSImage *)avatar forIdentifier:(NSString *)identifier
{
	NSAssert(avatar, @"avatar is nil");
	NSAssert(identifier, @"identifier is nil");
	
	dispatch_barrier_async(gValuesQueue, ^{
		gAvatarCache[identifier] = avatar;
	});
}

+ (void)removeAvatarForIdentifier:(NSString *)identifier
{
	NSAssert(identifier, @"identifier is nil");
	
	dispatch_barrier_async(gValuesQueue, ^{
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
		
	if ([host isEqualToString:@"medias"])
		[self handleMedias];
	else if ([host isEqualToString:@"theme"])
		[self handleTheme];
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

- (void)handleMedias
{
	// Check parameters.
	NSURL	*url = self.request.URL;
	NSArray	*parameters = url.pathComponents;

	if (parameters.count < 3)
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Parameter error" code:0 userInfo:@{}]];
		return;
	}
	
	// Extract parameters.
	NSString	*name = parameters[1];
	NSString	*size = parameters[2];
	
	if ([name isEqualToString:@"avatar"])
	{
		if (parameters.count < 4)
		{
			[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Parameter error" code:0 userInfo:@{}]];
			return;
		}
		
		NSString *identifier = parameters[3];
		
		// Send avatar.
		dispatch_async(gValuesQueue, ^{
			
			// > Get avatar.
			NSImage *avatar = gAvatarCache[identifier];
			
			if (!avatar)
			{
				[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Avatar not found" code:404 userInfo:@{}]];
				return;
			}
			
			// > Create image.
			NSImage *result = nil;
			
			if ([size isEqualToString:@"1x"])
			{
				result = [NSImage imageWithSize:NSMakeSize(32, 32) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
					[avatar drawInRect:NSMakeRect(0, 0, 32, 32) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
					return YES;
				}];
			}
			else if ([size isEqualToString:@"2x"])
			{
				result = [NSImage imageWithSize:NSMakeSize(64, 64) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
					[avatar drawInRect:NSMakeRect(0, 0, 64, 64) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
					return YES;
				}];
			}
			else
			{
				[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"unknow media size" code:404 userInfo:@{}]];
				return;
			}
			
			// Generate TIFF.
			NSData *data = result.TIFFRepresentation;
			
			if (!data)
			{
				[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"internal error" code:500 userInfo:@{}]];
				return;
			}
			
			// Build response.
			NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:@"image/tiff" expectedContentLength:(NSInteger)data.length textEncodingName:nil];
			
			// Send response + content.
			[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
			[self.client URLProtocol:self didLoadData:data];
			[self.client URLProtocolDidFinishLoading:self];
		});
	}
	else if ([name isEqualToString:@"error"])
	{
		if (parameters.count < 4)
		{
			[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Parameter error" code:0 userInfo:@{}]];
			return;
		}
		
		NSString *type = parameters[3];
		
		if ([type isEqualToString:@"button"])
		{
			// Handle name.
			NSSize	targetSize = NSZeroSize;
			CGFloat	targetFontSize = 0;
			
			if ([size isEqualToString:@"1x"])
			{
				targetSize = NSMakeSize(20, 20);
				targetFontSize = 14;
			}
			else if ([size isEqualToString:@"2x"])
			{
				targetSize = NSMakeSize(40, 40);
				targetFontSize = 28;
			}
			else
			{
				[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"unknow media size" code:404 userInfo:@{}]];
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
			
			NSData *data = image.TIFFRepresentation;
			
			// Build response.
			NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:@"image/tiff" expectedContentLength:(NSInteger)data.length textEncodingName:nil];
			
			// Send response + content.
			[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
			[self.client URLProtocol:self didLoadData:data];
			[self.client URLProtocolDidFinishLoading:self];
		}
		else
		{
			[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Error type not found" code:0 userInfo:@{}]];
		}
	}
	else
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Media name not found" code:0 userInfo:@{}]];
	}
}

- (void)handleTheme
{
	NSURL		*url = self.request.URL;
	NSArray		*parameters = url.pathComponents;
	NSString	*identifier = nil;
	NSString	*resName = nil;

	if (parameters.count < 3)
	{
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Parameter error" code:0 userInfo:@{}]];
		return;
	}
	
	identifier = parameters[1];
	resName = parameters[2];
	
	// Handle theme resource.
	dispatch_async(gValuesQueue, ^{
		
		// > Get theme.
		TCTheme *theme = gThemeCache[identifier];
		
		if (!theme)
		{
			[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Theme not found" code:404 userInfo:@{}]];
			return;
		}
		
		// > Get resource.
		NSDictionary	*resources = theme.chatTheme[TCThemeChatResourcesKey];
		NSDictionary	*resource = resources[resName];
		
		if (!resource)
		{
			[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Resource not found" code:404 userInfo:@{}]];
			return;
		}
		
		// > Get data.
		NSData		*data = resource[TCThemeChatResourceDataKey];
		NSString	*mime = resource[TCThemeChatResourceMIMEKey];
		
		if (!data || !mime)
		{
			[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Data not found" code:404 userInfo:@{}]];
			return;
		}
		
		// > Build response.
		NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:mime expectedContentLength:(NSInteger)data.length textEncodingName:nil];
		
		// Send response + content.
		[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
		[self.client URLProtocol:self didLoadData:data];
		[self.client URLProtocolDidFinishLoading:self];
	});
}

@end


NS_ASSUME_NONNULL_END
