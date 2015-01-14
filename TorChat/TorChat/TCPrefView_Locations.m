//
//  TCPrefView_Locations.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2015 SourceMac. All rights reserved.
//

#import "TCPrefView_Locations.h"


/*
** TCPrefView_Locations
*/
#pragma mark - TCPrefView_Locations

@implementation TCPrefView_Locations


/*
** TCPrefView_Locations - Instance
*/
#pragma mark - TCPrefView_Locations - Instance

- (id)init
{
	self = [super initWithNibName:@"PrefView_Locations" bundle:nil];
	
	if (self)
	{
		
	}
	
	return self;
}



/*
** TCPrefView_Locations - TCPrefView
*/
#pragma mark - TCPrefView_Locations - TCPrefView

- (void)loadConfig
{
	// Load view.
	[self view];

}

- (void)saveConfig
{
}

@end


/*
 
 // Download path.
	NSString *path = [self.config pathForDomain:TConfigPathDomainDownloads];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
	{
 [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
 
 if ([[path lastPathComponent] isEqualToString:@"Downloads"])
 [[NSData data] writeToFile:[path stringByAppendingPathComponent:@".localized"] atomically:NO];
	}
	
	[_downloadPath setURL:[NSURL fileURLWithPath:path]];
 
 
 
 
 
 
 
 - (IBAction)pathChanged:(id)sender
 {
	NSString *path = [[_downloadPath URL] path];
	
	if (path)
	{
 [self.config setDomain:TConfigPathDomainDownloads place:TConfigPathPlaceAbsolute subpath:path];
 
 if ([[path lastPathComponent] isEqualToString:@"Downloads"])
 [[NSData data] writeToFile:[path stringByAppendingPathComponent:@".localized"] atomically:NO];
	}
	else
 NSBeep();
 }
 */