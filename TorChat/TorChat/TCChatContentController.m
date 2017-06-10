/*
 *  TCChatContentController.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
 *
 *  This file is part of TorChat.
 *
 *  TorProxifier is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  TorProxifier is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with TorProxifier.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <MediaLibrary/MediaLibrary.h>
#import <AVFoundation/AVFoundation.h>

#import <SMFoundation/SMFoundation.h>

#import "TCChatContentController.h"

#import "TCDropZoneView.h"
#import "TCColoredView.h"
#import "TCMediaCellView.h"

#import "TCKVOHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

#define TCChatContentLastPanelKey @"chat-content-last-panel"

#define TCChatContentCameraLastDeviceKey	@"chat-content-camera-last-device"
#define TCChatContentCameraSaveLocallyKey	@"chat-content-camera-save-locally"



/*
** Prototypes
*/
#pragma mark - Prototypes

static NSString *generateToken(void);



/*
** TCChatContentControllerProtocol
*/

@protocol TCChatContentControllerProtocol <NSObject>

@property (nullable, atomic) void (^contentHandler)(NSArray <NSDictionary *> *content);
@property (nullable, nonatomic) IBOutlet NSButton *barButton;

@property (nullable, nonatomic) id <TCConfigApp> configuration;

@end


/*
** TCMediaChatContentController - Interface
*/
#pragma mark - TCMediaChatContentController - Interface

@interface TCMediaChatContentController : NSViewController <TCChatContentControllerProtocol, NSTableViewDelegate, NSTableViewDataSource>
@property (nullable, nonatomic) IBOutlet NSButton *barButton;
@end



/*
** TCCameraChatContentController - Interface
*/
#pragma mark - TCCameraChatContentController - Interface

@interface TCCameraChatContentController : NSViewController <TCChatContentControllerProtocol>
@property (nullable, nonatomic) IBOutlet NSButton *barButton;
@end



/*
** TCFileChatContentController - Interface
*/
#pragma mark - TCFileChatContentController - Interface

@interface TCFileChatContentController : NSViewController <TCChatContentControllerProtocol>
@property (nullable, nonatomic) IBOutlet NSButton *barButton;
@end



/*
** TCChatContentController
*/
#pragma mark - TCChatContentController

@interface TCChatContentController ()
{
	dispatch_queue_t _userQueue;
	
	id <TCConfigApp> _configuration;
	
	NSViewController <TCChatContentControllerProtocol> * _currentController;
	
	// Outlets.
	IBOutlet NSView			*_contentView;
	IBOutlet NSImageView	*_barView;
	
	IBOutlet TCMediaChatContentController	*_mediaController;
	IBOutlet TCCameraChatContentController	*_cameraController;
	IBOutlet TCFileChatContentController	*_fileController;
}

@end


@implementation TCChatContentController


/*
** TCChatContentController - Instance
*/
#pragma mark - TCChatContentController - Instance

- (instancetype)initWithConfiguration:(id <TCConfigApp>)configuration
{
	self = [super initWithNibName:@"ChatContentView" bundle:nil];
	
	if (self)
	{
		_userQueue = dispatch_queue_create("com.torchat.content-controller.user", DISPATCH_QUEUE_SERIAL);
		_configuration = configuration;
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"dealloc TCChatContentController");
}



/*
** TCChatContentController - NSViewController
*/
#pragma mark - TCChatContentController - NSViewController

- (void)viewWillAppear
{
	[super viewWillAppear];

	// Set content handler.
	void (^contentHandler)(NSArray <NSDictionary *> *content) = self.contentHandler;
	
	if (contentHandler)
	{
		void (^dispatchContentHandler)(NSArray <NSDictionary *> *content) = ^(NSArray <NSDictionary *> *content) {
			dispatch_async(_userQueue, ^{
				contentHandler(content);
			});
		};
		
		_mediaController.contentHandler = dispatchContentHandler;
		_cameraController.contentHandler = dispatchContentHandler;
		_fileController.contentHandler = dispatchContentHandler;
	}
	else
	{
		_mediaController.contentHandler = nil;
		_cameraController.contentHandler = nil;
		_fileController.contentHandler = nil;
	}
	
	// Set configuration.
	_mediaController.configuration = _configuration;
	_cameraController.configuration = _configuration;
	_fileController.configuration = _configuration;
	
	// Select first panel.
	NSString *lastPanel = [_configuration generalSettingValueForKey:TCChatContentLastPanelKey];
	
	if (!lastPanel || [lastPanel isEqualToString:@"medias"])
		[self selectViewController:_mediaController];
	else if ([lastPanel isEqualToString:@"camera"])
		[self selectViewController:_cameraController];
	else if ([lastPanel isEqualToString:@"file"])
		[self selectViewController:_fileController];
}

- (void)viewDidDisappear
{
	[super viewDidDisappear];
	
	// Unset content handler.
	_mediaController.contentHandler = nil;
	_cameraController.contentHandler = nil;
	_fileController.contentHandler = nil;
	
	// Unset configuration.
	_mediaController.configuration = nil;
	_cameraController.configuration = nil;
	_fileController.configuration = nil;
	
	// Unset controller.
	_currentController = nil;
}



/*
** TCChatContentController - IBActions
*/
#pragma mark - TCChatContentController - IBActions

- (IBAction)doMediasView:(id)sender
{
	[_configuration setGeneralSettingValue:@"medias" forKey:TCChatContentLastPanelKey];
	[self selectViewController:_mediaController];
}

- (IBAction)doCameraView:(id)sender
{
	[_configuration setGeneralSettingValue:@"camera" forKey:TCChatContentLastPanelKey];
	[self selectViewController:_cameraController];
}

- (IBAction)doFileView:(id)sender
{
	[_configuration setGeneralSettingValue:@"file" forKey:TCChatContentLastPanelKey];
	[self selectViewController:_fileController];
}



/*
** TCChatContentController - Helpers
*/
#pragma mark - TCChatContentController - Helpers

- (void)selectViewController:(NSViewController <TCChatContentControllerProtocol> *)viewController
{
	if (_currentController == viewController || !viewController)
	{
		viewController.barButton.state = NSOnState;
		return;
	}
	
	// Remove old view.
	[_currentController.view removeFromSuperview];
	
	// Add new view.
	NSView *view = viewController.view;
	
	[_contentView addSubview:viewController.view];
	
	// Notify resize, so NSPopover can resize (else it print warning)
	void (^resizeHandler)(NSSize newSize) = self.resizeHandler;
	
	if (resizeHandler)
		resizeHandler(NSMakeSize(view.frame.size.width, view.frame.size.height + _barView.frame.size.height));
	
	// Add constrain.
	NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(view);
		
	[_contentView removeConstraints:_contentView.constraints];
	[_contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:viewsDictionary]];
	[_contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:viewsDictionary]];
	
	// Update bar button state.
	_currentController.barButton.state = NSOffState;
	viewController.barButton.state = NSOnState;

	// Hold view.
	_currentController = viewController;
}

@end



/*
** TCMediaChatContentController
*/
#pragma mark - TCMediaChatContentController

@interface TCMediaObjectEntry : NSObject

@property (nonatomic) MLMediaObject *object;

@property (nullable, nonatomic) NSImage *thumbnail;
@property (nonatomic) BOOL loadingThumbnail;

@end

@implementation TCMediaObjectEntry
@end

@interface TCMediaSourceEntry : NSObject

@property (nonatomic) MLMediaSource *source;

@property (nullable, nonatomic) NSMutableArray <TCMediaObjectEntry *> *objects;
@property (nonatomic) BOOL loadingObjects;

@end

@implementation TCMediaSourceEntry
@end



@implementation TCMediaChatContentController
{
	MLMediaLibrary	*_mediaLibrary;
	
	NSMutableArray <TCMediaSourceEntry *> * _sourcesEntries;
	
	dispatch_queue_t				_mediaLoadQueue;
	
	IBOutlet NSTableView			*_sourcesTableView;
	IBOutlet NSTableView			*_objectsTableView;

	IBOutlet NSProgressIndicator	*_sourceLoading;
	IBOutlet NSProgressIndicator	*_objectsLoading;
}

@synthesize contentHandler;
@synthesize configuration;


/*
** TCMediaChatContentController - NSViewController
*/
#pragma mark - TCMediaChatContentController - NSViewController

- (void)viewDidLoad
{
	[super viewDidLoad];

	_mediaLoadQueue = dispatch_queue_create("com.torchat.media-content-controller.load", DISPATCH_QUEUE_SERIAL);
}

- (void)viewWillAppear
{
	[super viewWillAppear];

	[_sourceLoading startAnimation:nil];
	
	_mediaLibrary = [[MLMediaLibrary alloc] initWithOptions:@{ }];
	
	// Install observer.
	[[TCKVOHelper sharedHelper] addObserverOnObject:_mediaLibrary forKeyPath:@"mediaSources" observationHandler:^(id<NSObject> object, id newContent) {
		
		dispatch_group_t loadGroup = dispatch_group_create();
		
		// > Fetch sources infos.
		NSArray *sources = ((NSDictionary *)newContent).allValues;
		
		for (MLMediaSource *source in sources)
		{
			dispatch_group_enter(loadGroup);
			
			[[TCKVOHelper sharedHelper] addObserverOnObject:source forKeyPath:@"rootMediaGroup.iconImage" observationHandler:^(id<NSObject>  _Nonnull sObject, id  _Nonnull groupIcon) {
				dispatch_group_leave(loadGroup);
			}];
			
			dispatch_group_enter(loadGroup);
			
			[[TCKVOHelper sharedHelper] addObserverOnObject:source forKeyPath:@"rootMediaGroup.name" observationHandler:^(id<NSObject>  _Nonnull sObject, id  _Nonnull groupIcon) {
				dispatch_group_leave(loadGroup);
			}];
		}
		
		// > Wait for info to be available.
		dispatch_group_notify(loadGroup, dispatch_get_main_queue(), ^{
			
			// >> Sort sources by name.
			NSArray *mediaSources = [sources sortedArrayUsingComparator:^NSComparisonResult(MLMediaSource * _Nonnull obj1, MLMediaSource * _Nonnull obj2) {
				return [obj1.rootMediaGroup.name compare:obj2.rootMediaGroup.name];
			}];
			
			// >> Build entries.
			_sourcesEntries = [[NSMutableArray alloc] init];
			
			for (MLMediaSource *mediaSource in mediaSources)
			{
				TCMediaSourceEntry *sourceEntry = [[TCMediaSourceEntry alloc] init];
				
				sourceEntry.source = mediaSource;
				
				[_sourcesEntries addObject:sourceEntry];
			}
			
			// >> Reload.
			[_sourceLoading stopAnimation:nil];
			[_sourcesTableView reloadData];
		});
	}];
}

- (void)viewWillDisappear
{
	[super viewWillDisappear];

	_mediaLibrary = nil;
	_sourcesEntries = nil;

	[_sourceLoading stopAnimation:nil];
	[_objectsLoading stopAnimation:nil];

	[_sourcesTableView reloadData];
	[_objectsTableView reloadData];
}



/*
** TCMediaChatContentController - NSTableViewDelegate
*/
#pragma mark - TCMediaChatContentController - NSTableViewDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == _sourcesTableView)
	{
		return (NSInteger)_sourcesEntries.count;
	}
	else if (tableView == _objectsTableView)
	{
		NSInteger sourceIndex = _sourcesTableView.selectedRow;
		
		if (sourceIndex < 0 || sourceIndex >= _sourcesEntries.count)
			return 0;
		
		TCMediaSourceEntry *sourceEntry = _sourcesEntries[(NSUInteger)sourceIndex];
		
		return (NSInteger)sourceEntry.objects.count;
	}
	
	return 0;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (tableView == _sourcesTableView)
	{
		if (row < 0 || row >= _sourcesEntries.count)
			return nil;
		
		NSTableCellView		*cellView = nil;
		TCMediaSourceEntry	*sourceEntry = _sourcesEntries[(NSUInteger)row];
		MLMediaSource		*mediaSource = sourceEntry.source;
		
		cellView = [tableView makeViewWithIdentifier:@"standard_cell" owner:self];

		cellView.imageView.image = mediaSource.rootMediaGroup.iconImage;
		cellView.textField.stringValue = mediaSource.rootMediaGroup.name;
		
		return cellView;
	}
	else if (tableView == _objectsTableView)
	{
		NSInteger sourceIndex = _sourcesTableView.selectedRow;
		
		if (sourceIndex < 0 || sourceIndex >= _sourcesEntries.count)
			return nil;
		
		TCMediaSourceEntry	*sourceEntry = _sourcesEntries[(NSUInteger)sourceIndex];
		id					object = sourceEntry.objects[(NSUInteger)row];
		
		if ([object isKindOfClass:[NSString class]])
		{
			NSTableCellView *cellView = nil;

			cellView = [tableView makeViewWithIdentifier:@"standard_text" owner:self];
			cellView.textField.stringValue = object;
			
			return cellView;
		}
		else if ([object isKindOfClass:[TCMediaObjectEntry class]])
		{
			TCMediaCellView		*cellView;
			TCMediaObjectEntry	*objectEntry = object;
			MLMediaObject		*mediaObject = objectEntry.object;
			NSString			*text = mediaObject.name;
			
			if (!text)
				text = mediaObject.URL.lastPathComponent;
			
			if (mediaObject.mediaType == MLMediaTypeImage || mediaObject.mediaType == MLMediaTypeMovie)
			{
				cellView = [tableView makeViewWithIdentifier:@"thumbnail_cell" owner:self];
				
				if (objectEntry.thumbnail)
					cellView.imageView.image = objectEntry.thumbnail;
				else
				{
					cellView.imageView.image = [NSImage imageNamed:@"static_loading"];
					
					if (objectEntry.loadingThumbnail == NO)
					{
						objectEntry.loadingThumbnail = YES;
						
						dispatch_async(_mediaLoadQueue, ^{
							
							NSImage	*image = nil;
							
							if (mediaObject.thumbnailURL)
								image = [[NSImage alloc] initWithContentsOfURL:mediaObject.thumbnailURL];

							if (!image)
								image = [NSImage imageWithSize:NSMakeSize(1, 1) flipped:NO drawingHandler:^BOOL(NSRect dstRect) { return YES; }];
							
							dispatch_async(dispatch_get_main_queue(), ^{
								objectEntry.thumbnail = image;
								objectEntry.loadingThumbnail = NO;
								[_objectsTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
							});
						});
					}
				}
			}
			else if (mediaObject.mediaType == MLMediaTypeAudio)
			{
				NSDictionary	*attributes = mediaObject.attributes;
				NSString		*artist = attributes[MLMediaObjectArtistKey];
				
				cellView = [tableView makeViewWithIdentifier:@"audio_cell" owner:self];
				
				if (artist)
					text = [NSString stringWithFormat:@"%@ (%@)", text, artist];
			}
			
			cellView.textField.stringValue = (text ?: @"");
			cellView.sizeTextField.stringValue = SMStringFromBytesAmount(mediaObject.fileSize);
			
			return cellView;
		}
	}
		
	return nil;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
	if (tableView == _sourcesTableView)
	{
		return NO;
	}
	else if (tableView == _objectsTableView)
	{
		NSInteger sourceIndex = _sourcesTableView.selectedRow;
		
		if (sourceIndex < 0 || sourceIndex >= _sourcesEntries.count)
			return NO;
		
		TCMediaSourceEntry	*sourceEntry = _sourcesEntries[(NSUInteger)sourceIndex];
		id					object = sourceEntry.objects[(NSUInteger)row];
		
		return [object isKindOfClass:[NSString class]];
	}
	
	return NO;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	if (tableView == _sourcesTableView)
	{
		// Not applicable.
	}
	else if (tableView == _objectsTableView)
	{
		NSInteger sourceIndex = _sourcesTableView.selectedRow;
		
		if (sourceIndex < 0 || sourceIndex >= _sourcesEntries.count)
			return tableView.rowHeight;
		
		TCMediaSourceEntry	*sourceEntry = _sourcesEntries[(NSUInteger)sourceIndex];
		id					object = sourceEntry.objects[(NSUInteger)row];
		
		if ([object isKindOfClass:[NSString class]])
		{
			static dispatch_once_t	onceToken;
			static CGFloat			rowHeight;
			
			dispatch_once(&onceToken, ^{
				NSView *cellView = [tableView makeViewWithIdentifier:@"standard_text" owner:self];
				
				rowHeight = cellView.bounds.size.height;
			});
			
			return rowHeight;
		}
		else if ([object isKindOfClass:[TCMediaObjectEntry class]])
		{
			TCMediaObjectEntry	*objectEntry = object;
			MLMediaObject		*mediaObject = objectEntry.object;

			if (mediaObject.mediaType == MLMediaTypeImage || mediaObject.mediaType == MLMediaTypeMovie)
			{
				static dispatch_once_t	onceToken;
				static CGFloat			rowHeight;
				
				dispatch_once(&onceToken, ^{
					NSView *cellView = [tableView makeViewWithIdentifier:@"thumbnail_cell" owner:self];
					
					rowHeight = cellView.bounds.size.height;
				});
				
				return rowHeight;
			}
			else if (mediaObject.mediaType == MLMediaTypeAudio)
			{
				static dispatch_once_t	onceToken;
				static CGFloat			rowHeight;
				
				dispatch_once(&onceToken, ^{
					NSView *cellView = [tableView makeViewWithIdentifier:@"audio_cell" owner:self];
					
					rowHeight = cellView.bounds.size.height;
				});
				
				return rowHeight;
			}
		}
	}
	
	return tableView.rowHeight;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	if (tableView == _sourcesTableView)
		return YES;
	else if (tableView == _objectsTableView)
		return NO;
	
	return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if (aNotification.object == _sourcesTableView)
	{
		NSInteger row = _sourcesTableView.selectedRow;
		
		if (row < 0 || row >= _sourcesEntries.count)
			return;
		
		TCMediaSourceEntry *sourceEntry = _sourcesEntries[(NSUInteger)row];
		
		// Load objects if necessary.
		if (sourceEntry.objects == nil)
		{
			[_objectsLoading startAnimation:nil];

			// > If already loading, do nothing.
			if (sourceEntry.loadingObjects)
				return;
			
			sourceEntry.loadingObjects = YES;

			// > Load objects.
			MLMediaSource	*mediaSource = sourceEntry.source;
			MLMediaGroup	*mediaGroup = mediaSource.rootMediaGroup;
			
			[[TCKVOHelper sharedHelper] addObserverOnObject:mediaGroup forKeyPath:@"mediaObjects" oneShot:YES observationQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) observationHandler:^(id<NSObject>  _Nonnull object, id  _Nonnull newContent) {
								
				// > Hold new objects.
				NSMutableArray *objects = [[NSMutableArray alloc] init];
				NSMutableArray *audioObjects = [[NSMutableArray alloc] init];
				NSMutableArray *imageObjects = [[NSMutableArray alloc] init];
				NSMutableArray *movieObjects = [[NSMutableArray alloc] init];

				for (MLMediaObject *mediaObject in newContent)
				{
					if (mediaObject.URL == nil)
						continue;
					
					TCMediaObjectEntry *objectEntry = [[TCMediaObjectEntry alloc] init];
					
					objectEntry.object = mediaObject;
					
					if (mediaObject.mediaType == MLMediaTypeAudio)
						[audioObjects addObject:objectEntry];
					else if (mediaObject.mediaType == MLMediaTypeImage)
						[imageObjects addObject:objectEntry];
					else if (mediaObject.mediaType == MLMediaTypeMovie)
						[movieObjects addObject:objectEntry];
				}
				
				[audioObjects sortUsingComparator:^NSComparisonResult(TCMediaObjectEntry * _Nonnull obj1, TCMediaObjectEntry * _Nonnull obj2) {
					return [obj2.object.modificationDate compare:obj1.object.modificationDate];
				}];
				
				[imageObjects sortUsingComparator:^NSComparisonResult(TCMediaObjectEntry * _Nonnull obj1, TCMediaObjectEntry * _Nonnull obj2) {
					return [obj2.object.modificationDate compare:obj1.object.modificationDate];
				}];
				
				[movieObjects sortUsingComparator:^NSComparisonResult(TCMediaObjectEntry * _Nonnull obj1, TCMediaObjectEntry * _Nonnull obj2) {
					return [obj2.object.modificationDate compare:obj1.object.modificationDate];
				}];
				
				if (audioObjects.count > 0)
				{
					[objects addObject:NSLocalizedString(@"chat_media_audio", @"")];
					[objects addObjectsFromArray:audioObjects];
				}
				
				if (imageObjects.count > 0)
				{
					[objects addObject:NSLocalizedString(@"chat_media_images", @"")];
					[objects addObjectsFromArray:imageObjects];
				}
				
				if (movieObjects.count > 0)
				{
					[objects addObject:NSLocalizedString(@"chat_media_movies", @"")];
					[objects addObjectsFromArray:movieObjects];
				}
				
				// > Update entry.
				dispatch_async(dispatch_get_main_queue(), ^{
					
					sourceEntry.objects = objects;
					sourceEntry.loadingObjects = NO;
					
					// > Reload if still selected.
					NSInteger currentRow = _sourcesTableView.selectedRow;
					
					if (currentRow == row)
					{
						[_objectsLoading stopAnimation:nil];
						[_objectsTableView reloadData];
					}
				});
			}];
		}
		else
		{
			[_objectsLoading stopAnimation:nil];
		}
		
		// Reload objects.
		[_objectsTableView reloadData];
	}
}



/*
** TCMediaChatContentController - IBActions
*/
#pragma mark - TCMediaChatContentController - IBActions

- (IBAction)doGiveMedia:(id)sender
{
	// Get content handler.
	void (^lContentHandler)(NSArray <NSDictionary *> *content) = self.contentHandler;
	
	if (!lContentHandler)
	{
		NSBeep();
		return;
	}
	
	// Get source.
	NSInteger sourceRowIndex = _sourcesTableView.selectedRow;
	
	if (sourceRowIndex < 0 || sourceRowIndex >= _sourcesEntries.count)
		return;
	
	TCMediaSourceEntry *sourceEntry = _sourcesEntries[(NSUInteger)sourceRowIndex];
	
	// Get selected object.
	NSInteger objectRowIndex = [_objectsTableView rowForView:sender];
	
	if (objectRowIndex < 0 || objectRowIndex >= sourceEntry.objects.count)
		return;
	
	id object = sourceEntry.objects[(NSUInteger)objectRowIndex];
	
	if ([object isKindOfClass:[TCMediaObjectEntry class]] == NO)
	{
		NSBeep();
		return;
	}
	
	// Give content.
	NSString *path = ((TCMediaObjectEntry *)object).object.URL.path;
	
	if (!path)
		return;
	
	lContentHandler(@[ @{ TCChatContentControllerTypeKey : TCChatContentControllerTypeFileKey, TCChatContentControllerContentKey: path } ]);
}

@end



/*
** TCCameraChatContentController
*/
#pragma mark - TCCameraChatContentController

@implementation TCCameraChatContentController
{
	NSArray						*_devices;
	AVCaptureDeviceInput		*_inputDevice;
	AVCaptureSession			*_session;
	AVCaptureStillImageOutput	*_stillImageOutput;
	
	
	IBOutlet NSView			*_cameraView;
	IBOutlet NSPopUpButton	*_devicesPopup;
	IBOutlet NSButton		*_saveLocally;
	IBOutlet TCColoredView	*_footband;
}


@synthesize contentHandler;
@synthesize configuration;


/*
** TCCameraChatContentController - NSViewController
*/
#pragma mark - TCCameraChatContentController - NSViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	_footband.color = [NSColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.7];
}

- (void)viewWillAppear
{
	[super viewWillAppear];

	// Set save locally state.
	NSNumber *saveLocally = [configuration generalSettingValueForKey:TCChatContentCameraSaveLocallyKey];
	
	if (saveLocally)
	{
		if (saveLocally.boolValue)
			_saveLocally.state = NSOnState;
		else
			_saveLocally.state = NSOffState;
	}
	else
		_saveLocally.state = NSOnState;

	
	// Create session.
	_session = [[AVCaptureSession alloc] init];
	
	_session.sessionPreset = AVCaptureSessionPresetPhoto;
	
	// Build devices list.
	_devices = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] arrayByAddingObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeMuxed]];
	
	// Select last camera camera.
	NSString		*lastDevice = [configuration generalSettingValueForKey:TCChatContentCameraLastDeviceKey];
	AVCaptureDevice	*defaultDevice;
	
	if (lastDevice)
	{
		for (AVCaptureDevice *device in _devices)
		{
			if ([device.uniqueID isEqualToString:lastDevice])
			{
				defaultDevice = device;
				break;
			}
		}
	}
	
	// Select default camera.
	if (!defaultDevice)
	{
		for (AVCaptureDevice *device in _devices)
		{
			if (device.position == AVCaptureDevicePositionFront)
				defaultDevice = device;
		}
	}
	
	if (!defaultDevice)
		defaultDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	
	
	// Build device popup.
	[_devicesPopup removeAllItems];
	
	for (AVCaptureDevice *device in _devices)
		[_devicesPopup addItemWithTitle:device.localizedName];
	
	[_devicesPopup sizeToFit];
	
	// Select device.
	[self useCameraDevice:defaultDevice];
	
	// Show preview.
	CALayer *previewViewLayer = _cameraView.layer;
	AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
	
	captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	captureVideoPreviewLayer.frame = previewViewLayer.bounds;
	captureVideoPreviewLayer.autoresizingMask = (kCALayerWidthSizable | kCALayerHeightSizable);
	
	previewViewLayer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
	
	[previewViewLayer addSublayer:captureVideoPreviewLayer];
	
	// Create still image output.
	_stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
	
	_stillImageOutput.outputSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCMPixelFormat_32BGRA) };
	
	[_session addOutput:_stillImageOutput];
}

- (void)viewDidAppear
{
	[super viewDidAppear];
	
	[_session startRunning];
}

- (void)viewWillDisappear
{
	[super viewWillDisappear];

	// Stop camera.
	[_session stopRunning];
	
	_devices = nil;
	_inputDevice = nil;
	_session = nil;
	_stillImageOutput = nil;
	
	// Save config.
	[configuration setGeneralSettingValue:@(_saveLocally.state == NSOnState) forKey:TCChatContentCameraSaveLocallyKey ];
}



/*
** TCCameraChatContentController - IBActions
*/
#pragma mark - TCCameraChatContentController - IBActions

- (IBAction)doCameraSelect:(id)sender
{
	// Get device.
	NSInteger index = _devicesPopup.indexOfSelectedItem;
	
	if (index < 0 || index >= _devices.count)
	{
		NSBeep();
		return;
	}
	
	[self useCameraDevice:_devices[(NSUInteger)index]];
}

- (IBAction)doCameraSnapshot:(NSButton *)sender
{
	// Get content handler.
	void (^lContentHandler)(NSArray <NSDictionary *> *content) = self.contentHandler;
	
	if (!lContentHandler)
		return;
	
	// Deactivate button.
	sender.enabled = NO;
	
	// Search connection port.
	AVCaptureConnection *videoConnection = nil;
	
	for (AVCaptureConnection *connection in _stillImageOutput.connections)
	{
		for (AVCaptureInputPort *port in connection.inputPorts)
		{
			if ([port.mediaType isEqual:AVMediaTypeVideo])
			{
				videoConnection = connection;
				break;
			}
		}
		
		if (videoConnection)
			break;
	}
	
	if (!videoConnection)
	{
		sender.enabled = YES;
		NSBeep();
		return;
	}
	
	BOOL saveLocally = (_saveLocally.state == NSOnState);
	
	// Create "snapshot".
	[_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
		
		// Create core image.
		CVImageBufferRef	imageBuffer = CMSampleBufferGetImageBuffer(imageSampleBuffer);
		NSDictionary		*attachments = (__bridge_transfer NSDictionary *)CMCopyDictionaryOfAttachments(kCFAllocatorDefault, imageSampleBuffer, kCMAttachmentMode_ShouldPropagate);
		CIImage				*image = [[CIImage alloc] initWithCVImageBuffer:imageBuffer options:attachments];
		CGRect				imgRect = image.extent;
		
		// Create image.
		NSImage *targetImage = [NSImage imageWithSize:NSMakeSize(imgRect.size.width, imgRect.size.height) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
			[image drawInRect:NSMakeRect(0, 0, imgRect.size.width, imgRect.size.height) fromRect:NSMakeRect(0, 0, imgRect.size.width, imgRect.size.height) operation:NSCompositeCopy fraction:1.0];
			return YES;
		}];
		
		// Create JPEG.
		CGImageRef ref = [targetImage CGImageForProposedRect:NULL context:nil hints:nil];
		
		if (ref)
		{
			NSBitmapImageRep *bitmapImage = [[NSBitmapImageRep alloc] initWithCGImage:ref];
			
			if (bitmapImage)
			{
				NSData *jpegData = [bitmapImage representationUsingType:NSJPEGFileType properties:@{ NSImageCompressionFactor : @(0.85) }];
				
				if (jpegData)
					lContentHandler(@[ @{ TCChatContentControllerTypeKey: TCChatContentControllerTypeRawKey, TCChatContentControllerContentKey : jpegData, TCChatContentControllerNameKey : [NSString stringWithFormat:@"capture_%@.jpg", generateToken()], TCChatContentControllerSaveKey: @(saveLocally) } ]);
			}
		}
		
		// Reactivate button.
		dispatch_async(dispatch_get_main_queue(), ^{
			sender.enabled = YES;
		});
	}];
}



/*
** TCCameraChatContentController - Helpers
*/
#pragma mark - TCCameraChatContentController - Helpers

- (void)useCameraDevice:(AVCaptureDevice *)device
{
	if (!device || device == _inputDevice.device)
		return;
	
	// Create input device.
	NSError					*error = nil;
	AVCaptureDeviceInput	*input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
	
	if (!input)
	{
		NSLog(@"Error: Trying to open camera: %@", error);
		return;
	}
	
	// Use this new input in session.
	if (_inputDevice)
		[_session removeInput:_inputDevice];
	[_session addInput:input];
	
	_inputDevice = input;
	
	// Select popup.
	NSUInteger index = [_devices indexOfObject:device];
	
	if (index != NSNotFound)
		[_devicesPopup selectItemAtIndex:(NSInteger)index];
	
	// Store device ID.
	[configuration setGeneralSettingValue:device.uniqueID forKey:TCChatContentCameraLastDeviceKey];
}

@end



/*
** TCFileChatContentController
*/
#pragma mark - TCFileChatContentController

@implementation TCFileChatContentController

@synthesize contentHandler;
@synthesize configuration;


/*
** TCFileChatContentController - NSViewController
*/
#pragma mark - TCFileChatContentController - NSViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	__weak TCFileChatContentController *weakSelf = self;
	
	TCDropZoneView	*dropZone = (TCDropZoneView *)self.view;

	// Compute string size.
	NSString		*dropString = NSLocalizedString(@"chat_file_drop", @"");
	NSDictionary	*dropStringAttributes = @{ NSForegroundColorAttributeName : dropZone.dashColor, NSFontAttributeName : [NSFont systemFontOfSize:20] };
	NSSize			dropStringSize = [dropString sizeWithAttributes:dropStringAttributes];
	
	NSSize			dropZoneSize = [dropZone computeSizeForSymmetricalDashesWithMinWidth:(dropStringSize.width + 50.0) minHeight:(dropStringSize.width + 50.0) / 1.61803398875];
	
	[dropZone addConstraint:[NSLayoutConstraint constraintWithItem:dropZone attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:dropZoneSize.width]];
	[dropZone addConstraint:[NSLayoutConstraint constraintWithItem:dropZone attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:dropZoneSize.height]];
	
	dropZone.dropString = [[NSAttributedString alloc] initWithString:dropString attributes:@{ NSForegroundColorAttributeName : dropZone.dashColor, NSFontAttributeName : [NSFont systemFontOfSize:20] }];
	dropZone.droppedFilesHandler = ^(NSArray * _Nonnull files) {
		
		TCFileChatContentController *strongSelf = weakSelf;
		
		if (!strongSelf)
			return;
		
		void (^lContentHandler)(NSArray <NSDictionary *> *content) = strongSelf.contentHandler;
		
		if (!lContentHandler)
			return;
		
		NSMutableArray *items = [NSMutableArray new];
		
		for (NSString *file in files)
		{
			BOOL isDirectory = NO;
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDirectory] == NO)
				continue;
			
			if (isDirectory == YES)
				continue;
			
			if ([[NSFileManager defaultManager] isReadableFileAtPath:file] == NO)
				continue;
			
			[items addObject:@{ TCChatContentControllerTypeKey: TCChatContentControllerTypeFileKey, TCChatContentControllerContentKey : file }];
		}
		
		lContentHandler(items);
	};
}

@end



/*
** C-Tools
*/
#pragma mark - C Tools

static NSString *generateToken(void)
{
	static uint8_t	table[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789zZ";
	uint8_t			token[12];
	uint8_t			tokenStr[16];
	typedef struct {
		uint8_t pk1:6;
		uint8_t pk2:6;
		uint8_t pk3:6;
		uint8_t pk4:6;
	} __attribute__ ((packed)) tPack3; // 24 bits / 3 octets
	
	arc4random_buf(token, sizeof(token));
	memset(tokenStr, 0, sizeof(tokenStr));
	
	for (uint8_t i = 0, j = 0; i < sizeof(token) && j < sizeof(tokenStr); i += 3, j += 4)
	{
		tPack3 *pack3 = (tPack3 *)&token[i];
		
		tokenStr[j] = table[pack3->pk1];
		tokenStr[j + 1] = table[pack3->pk2];
		tokenStr[j + 2] = table[pack3->pk3];
		tokenStr[j + 3] = table[pack3->pk4];
	}
	
	return [[NSString alloc] initWithBytes:tokenStr length:sizeof(tokenStr) encoding:NSASCIIStringEncoding];
}

NS_ASSUME_NONNULL_END
