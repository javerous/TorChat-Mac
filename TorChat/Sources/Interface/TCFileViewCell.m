/*
 *  TCFileViewCell.m
 *
 *  Copyright 2013 Avérous Julien-Pierre
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



#import "TCFileViewCell.h"

#import "TCFilesCommon.h"
#import "TCButton.h"



/*
** Globals
*/
#pragma mark - Globals

static NSMutableDictionary *_cgitems = nil;



/*
** Prototypes
*/
#pragma mark - Prototypes

NSString *NSStringFromFileSize(uint64_t size);



/*
** TCFileCellItems (Interface)
*/
#pragma mark - TCFileCellItems (Interface)

@interface TCFileCellItems : NSObject
{
@private
	NSString			*_uuid;
	NSString			*_address;
	tcfile_way			_way;
}

// -- Properties --
@property (strong, nonatomic) NSProgressIndicator	*indicator;
@property (strong, nonatomic) NSButton				*icon;
@property (strong, nonatomic) TCButton				*showFile;
@property (strong, nonatomic) TCButton				*cancelFile;

// -- Constructors --
+ (TCFileCellItems *)cellItemsWithIcon:(NSImage *)image onView:(NSView *)view withUUID:(NSString *)uuid withAddress:(NSString *)address withWay:(tcfile_way)way;

- (id)initWithIcon:(NSImage *)image onView:(NSView *)view withUUID:(NSString *)uuid withAddress:(NSString *)address withWay:(tcfile_way)way;
@end



/*
** TCFileCellItems (Implementation)
*/
#pragma mark - TCFileCellItems (Implementation)

@implementation TCFileCellItems

+ (TCFileCellItems *)cellItemsWithIcon:(NSImage *)image onView:(NSView *)view withUUID:(NSString *)uuid withAddress:(NSString *)address withWay:(tcfile_way)way
{
	return [[[self class] alloc] initWithIcon:image onView:view withUUID:uuid withAddress:address withWay:way];
}

- (id)initWithIcon:(NSImage *)image onView:(NSView *)view withUUID:(NSString *)uuid withAddress:(NSString *)address withWay:(tcfile_way)way
{
	self = [super init];
	
	if (self)
	{
		_uuid =  uuid;
		_address = address;
		_way = way;
		
		// -- Build Indicator --
		_indicator = [[NSProgressIndicator alloc] init];
		
		[_indicator setStyle:NSProgressIndicatorBarStyle];
		[_indicator setIndeterminate:NO];
		[_indicator setControlSize:NSSmallControlSize];
		[_indicator setMinValue:0.0];
		[_indicator setMaxValue:1.0];
		[_indicator setDoubleValue:0.5];
		[_indicator startAnimation:nil];
		[_indicator setHidden:NO];
		[_indicator sizeToFit];
		
		[view addSubview:_indicator];
		
		
		// -- Build Icon Button --
		_icon = [[NSButton alloc] init];
		
		[_icon setBordered:NO];
		[_icon setImage:image];
		[_icon setButtonType:NSMomentaryChangeButton];
		[_icon.cell setImageScaling:NSImageScaleProportionallyUpOrDown];
		[_icon setTarget:self];
		[_icon setAction:@selector(iconAction:)];
		
		[view addSubview:_icon];
		
		
		// -- Build Show Button --
		_showFile  = [[TCButton alloc] init];
		
		[_showFile setImage:[NSImage imageNamed:@"file_reveal"]];
		[_showFile setRollOverImage:[NSImage imageNamed:@"file_reveal_rollover"]];
		[_showFile setPushImage:[NSImage imageNamed:@"file_reveal_pushed"]];
		[_showFile setTarget:self];
		[_showFile setAction:@selector(revealAction:)];
		
		[view addSubview:_showFile];
		
		
		// -- Build Cancel Button --
		_cancelFile = [[TCButton alloc] init];
		
		[_cancelFile setImage:[NSImage imageNamed:@"file_stop"]];
		[_cancelFile setRollOverImage:[NSImage imageNamed:@"file_stop_rollover"]];
		[_cancelFile setPushImage:[NSImage imageNamed:@"file_stop_pushed"]];
		[_cancelFile setTarget:self];
		[_cancelFile setAction:@selector(cancelAction:)];
		
		[view addSubview:_cancelFile];
		
	}
	
	return self;
}

- (void)dealloc
{
	[_indicator removeFromSuperview];
	
	[_icon removeFromSuperview];
	
	[_showFile setDelegate:nil];
	[_showFile removeFromSuperview];
	
	[_cancelFile setDelegate:nil];
	[_cancelFile removeFromSuperview];
}

- (void)iconAction:(id)sender
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:_uuid, @"uuid", _address, @"address", [NSNumber numberWithInt:_way], @"way", nil];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:TCFileCellOpenNotify object:_uuid userInfo:dict];
}

- (void)revealAction:(id)sender
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:_uuid, @"uuid", _address, @"address", [NSNumber numberWithInt:_way], @"way", nil];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:TCFileCellRevealNotify object:_uuid userInfo:dict];
}

- (void)cancelAction:(id)sender
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:_uuid, @"uuid", _address, @"address", [NSNumber numberWithInt:_way], @"way", nil];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:TCFileCellCancelNotify object:_uuid userInfo:dict];
}

@end



/*
** TCFileViewCell - Private
*/
#pragma mark - TCFileViewCell - Private

@interface TCFileViewCell ()
{
	NSDictionary *file;
}

@end



/*
** TCFileViewCell
*/
#pragma mark - TCFileViewCell

@implementation TCFileViewCell


/*
** TCFileViewCell - Instance
*/
#pragma mark - TCFileViewCell - Instance

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
    if (self)
	{
		static dispatch_once_t		pred;
		
		dispatch_once(&pred, ^{
			_cgitems = [[NSMutableDictionary alloc] init];
			
		});
		
		[[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(removeFile:) name:TCFileRemovingNotify object:nil];
    }
    
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)copyWithZone:(NSZone *)zone
{
    TCFileViewCell *cell = (TCFileViewCell *)[super copyWithZone:zone];
	
	cell->file = file;

    return cell;
}



/*
** TCFileViewCell - Draw
*/
#pragma mark - TCFileViewCell - Draw

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[super drawInteriorWithFrame:cellFrame inView:controlView];

	NSString		*uuid = [file objectForKey:TCFileUUIDKey];
	NSImage			*icon = [file objectForKey:TCFileIconKey];
	NSString		*path = [file objectForKey:TCFileFilePathKey];
	NSString		*bname = [file objectForKey:TCFileBuddyNameKey];
	NSString		*baddress = [file objectForKey:TCFileBuddyAddressKey];
	NSString		*txtStatus = [file objectForKey:TCFileStatusTextKey];
	tcfile_status	status = (tcfile_status)[[file objectForKey:TCFileStatusKey] intValue];
	tcfile_way		way = (tcfile_way)[[file objectForKey:TCFileWayKey] intValue];
	uint64_t		fsize = [[file objectForKey:TCFileSizeKey] unsignedLongLongValue];
	uint64_t		fsize_comp = [[file objectForKey:TCFileCompletedKey] unsignedLongLongValue];
	double			fdone = (double)fsize_comp / (double)fsize;
	NSColor			*txtColor = nil;
	int				deltay = 0;
	
	if (!uuid)
		return;
	
	
	// -- Get (or build) the cell item set --
	TCFileCellItems	*items = [_cgitems  objectForKey:[NSString stringWithFormat:@"%@/%i", uuid, way]];
	
	if (!items)
	{
		items = [TCFileCellItems cellItemsWithIcon:icon onView:controlView withUUID:uuid withAddress:baddress withWay:way];
		
		[_cgitems setObject:items forKey:[NSString stringWithFormat:@"%@/%i", uuid, way]];
	}

	
	// -- Manage Icon --
	NSRect iconRect = NSMakeRect(cellFrame.origin.x + 5, cellFrame.origin.y + 10, 50, 50);
	
	[items.icon setFrame:iconRect];
	

	// -- Manage Indictor --
	BOOL isIndicator = NO;
	
	if (status == tcfile_status_finish || status == tcfile_status_cancel || status == tcfile_status_stoped || status == tcfile_status_error)
		isIndicator = NO;
	else
		isIndicator = YES;
	
	if (isIndicator)
	{
		NSRect progressRect = NSMakeRect(cellFrame.origin.x + 60, cellFrame.origin.y + 40, cellFrame.size.width - 107, cellFrame.size.height);
		
		[items.indicator setFrame:progressRect];
		[items.indicator sizeToFit];
		
		[items.indicator setDoubleValue:fdone];
		
		[items.indicator setHidden:NO];
	}
	else
		[items.indicator setHidden:YES];
	
	
	// -- Draw FileName --
	if ([self isHighlighted])
		txtColor = [NSColor whiteColor];
	else
		txtColor = [NSColor blackColor];
	
	if (isIndicator)
		deltay = 4;
	else
		deltay = 10;
	
	NSString		*name = [path lastPathComponent];
	NSDictionary	*fnAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSFont systemFontOfSize:12],	NSFontAttributeName,
									txtColor,						NSForegroundColorAttributeName,
									nil];
	
	[name drawAtPoint:NSMakePoint(cellFrame.origin.x + 60, cellFrame.origin.y + deltay) withAttributes:fnAttribute];
	
	// -- Manage ToName --
	NSString		*wayTxt = nil;
	NSDictionary	*tnAttribute = [NSDictionary dictionaryWithObjectsAndKeys:	[NSFont fontWithName:@"Arial" size:10],	NSFontAttributeName,
									txtColor,								NSForegroundColorAttributeName,
									nil];
	
	if (way == tcfile_upload)
		wayTxt = NSLocalizedString(@"file_progress_to", @"");
	else if (way == tcfile_download)
		wayTxt = NSLocalizedString(@"file_progress_from", @"");
	
	if (isIndicator)
		deltay = 23;
	else
		deltay = 29;
	
	[[NSString stringWithFormat:@"%@ %@ (%@) - %@ %@ %@", wayTxt, bname, baddress, NSStringFromFileSize(fsize_comp), NSLocalizedString(@"file_progress_of", @""), NSStringFromFileSize(fsize)] drawAtPoint:NSMakePoint(cellFrame.origin.x + 60, cellFrame.origin.y + deltay) withAttributes:tnAttribute];
	
	
	// -- Manage Status --	
	if ([self isHighlighted])
		txtColor = [NSColor whiteColor];
	else
		txtColor = [NSColor grayColor];
	
	if (isIndicator)
		deltay = 52;
	else
		deltay = 46;
	
	NSDictionary	*stAttribute = [NSDictionary dictionaryWithObjectsAndKeys:	[NSFont fontWithName:@"Arial" size:9],	NSFontAttributeName,
																				txtColor,								NSForegroundColorAttributeName,
																				nil];
	
	[txtStatus drawAtPoint:NSMakePoint(cellFrame.origin.x + 60, cellFrame.origin.y + deltay) withAttributes:stAttribute];

	
	// -- Manage Cancel File --
	if (isIndicator)
	{
		NSRect cancelFileRect = NSMakeRect(cellFrame.size.width - 38, cellFrame.origin.y + 38, 14, 14);
		
		[items.cancelFile setFrame:cancelFileRect];
		[items.cancelFile setHidden:NO];
	}
	else
		[items.cancelFile setHidden:YES];

	
	
	// -- Manage Show File --
	NSRect showFileRect = NSMakeRect(cellFrame.size.width - 18, cellFrame.origin.y + 38, 14, 14);
	
	[items.showFile setFrame:showFileRect];
}



/*
** TCFileViewCell - Content
*/
#pragma mark - TCFileViewCell - Content

- (void)setObjectValue:(id < NSCopying >)object
{
	id obj = object;
	
	if ([obj isKindOfClass:[NSDictionary class]] == NO)
		return;
	
	file = obj;
}

- (id)objectValue
{
	return file;
}


/*
** TCFileViewCell - TCFileController Notification
*/
#pragma mark - TCFileViewCell - TCFileController Notification

+ (void)removeFile:(NSNotification *)notice
{
	NSDictionary	*info = [notice userInfo];
	NSString		*uuid = [info objectForKey:@"uuid"];
	tcfile_way		way = (tcfile_way)[[info objectForKey:@"way"] intValue];
	
	[_cgitems removeObjectForKey:[NSString stringWithFormat:@"%@/%i", uuid, way]];
}

@end



/*
** C Functions
*/
#pragma mark - C Functions

// == Render bytes ==
NSString *NSStringFromFileSize(uint64_t size)
{	
	uint64_t	gb = 0;
	float		fgb;
	uint64_t	mb = 0;
	float		fmb;
	uint64_t	kb = 0;
	float		fkb;
	uint64_t	b = 0;
	
	
	// Compute GB
	gb = size / (1024 * 1024 * 1024);
	fgb = (float)size / (float)(1024 * 1024 * 1024);
	size = size % (1024 * 1024 * 1024);
	
	// Compute MB
	mb = size / (1024 * 1024);
	fmb = (float)size / (float)(1024 * 1024);
	size = size % (1024 * 1024);
	
	// Compute KB
	kb = size / (1024);
	fkb = (float)size / (float)(1024);
	size = size % (1024);
	
	// Compute B
	b = size;

	
	if (gb)
	{
		if (mb)
			return [NSString stringWithFormat:@"%.02f %@", fgb, NSLocalizedString(@"file_gb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", gb, NSLocalizedString(@"file_gb", @"")];
	}
	else if (mb)
	{
		if (kb)
			return [NSString stringWithFormat:@"%.02f %@", fmb, NSLocalizedString(@"file_mb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", mb, NSLocalizedString(@"file_mb", @"")];
	}
	else if (kb)
	{
		if (b)
			return [NSString stringWithFormat:@"%.02f %@", fkb, NSLocalizedString(@"file_kb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", kb, NSLocalizedString(@"file_kb", @"")];
	}
	else if (b)
		return [NSString stringWithFormat:@"%llu %@", b, NSLocalizedString(@"file_b", @"")];
	
	return [NSString stringWithFormat:@"0 %@", NSLocalizedString(@"file_b", @"")];
}
