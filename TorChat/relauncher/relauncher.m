/*
 *  relauncher.m
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

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[])
{
	if (argc != 3)
		return -1;
	
	@autoreleasepool
	{
		NSString *bundlePath = @(argv[1]);
		NSString *processPID = @(argv[2]);

		dispatch_source_t exitSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)[processPID integerValue], DISPATCH_PROC_EXIT, dispatch_get_main_queue());
		
		dispatch_source_set_event_handler(exitSource, ^{
			
			dispatch_source_cancel(exitSource);
			
			NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:@[ bundlePath ]];
			
			[task waitUntilExit];
			
			exit(0);
		});
		
		dispatch_resume(exitSource);
		
		dispatch_main();
	}
}
