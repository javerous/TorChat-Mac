/*
 *  TCTimeHelper.m
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

#import <mach/mach_time.h>

#import "TCTimeHelper.h"


/*
** Functions
*/
#pragma mark - Functions

double TCTimeStamp(void)
{
	static dispatch_once_t onceToken;
	static double timeConvert = 0.0;
	
	dispatch_once(&onceToken, ^{
		mach_timebase_info_data_t timeBase;
		
		mach_timebase_info(&timeBase);
		
		timeConvert = (double)timeBase.numer / (double)timeBase.denom / 1000000000.0;
	});
	
	return (double)mach_absolute_time() * timeConvert;
}

