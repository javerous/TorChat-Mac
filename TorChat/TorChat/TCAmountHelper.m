/*
 *  TCAmountHelper.m
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

#import "TCAmountHelper.h"


/*
** Funbctions
*/
#pragma mark - Functions

NSString * TCStringFromBytesAmount(uint64_t size)
{
	// Compute GB.
	uint64_t	gb = 0;
	float		fgb;
	
	gb = size / (1024 * 1024 * 1024);
	fgb = (float)size / (float)(1024 * 1024 * 1024);
	size = size % (1024 * 1024 * 1024);
	
	// Compute MB.
	uint64_t	mb = 0;
	float		fmb;
	
	mb = size / (1024 * 1024);
	fmb = (float)size / (float)(1024 * 1024);
	size = size % (1024 * 1024);
	
	// Compute KB.
	uint64_t	kb = 0;
	float		fkb;
	
	kb = size / (1024);
	fkb = (float)size / (float)(1024);
	size = size % (1024);
	
	// Compute B.
	uint64_t b = 0;

	b = size;
	
	
	// Compose result.
	if (gb)
	{
		if (mb)
			return [NSString stringWithFormat:@"%.01f %@", fgb, NSLocalizedString(@"size_gb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", gb, NSLocalizedString(@"size_gb", @"")];
	}
	else if (mb)
	{
		if (kb)
			return [NSString stringWithFormat:@"%.01f %@", fmb, NSLocalizedString(@"size_mb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", mb, NSLocalizedString(@"size_mb", @"")];
	}
	else if (kb)
	{
		if (b)
			return [NSString stringWithFormat:@"%.01f %@", fkb, NSLocalizedString(@"size_kb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", kb, NSLocalizedString(@"size_kb", @"")];
	}
	else if (b)
		return [NSString stringWithFormat:@"%llu %@", b, NSLocalizedString(@"size_b", @"")];
	
	return [NSString stringWithFormat:@"0 %@", NSLocalizedString(@"size_b", @"")];
}

NSString * TCStringFromSecondsAmount(NSTimeInterval doubleSeconds)
{
	NSUInteger seconds = (NSUInteger)doubleSeconds;
	
	// Compute days.
	NSUInteger days;
	
	days = seconds / (24 * 3600);
	seconds = seconds % (24 * 3600);

	// Compute hours.
	NSUInteger hours;
	
	hours = seconds / 3600;
	seconds = seconds % (3600);
	
	// Compute minutes.
	NSUInteger minutes;
	
	minutes = seconds / 60;
	seconds = seconds % (60);
	
	// Compose result.
	if (days)
		return [NSString stringWithFormat:@"%lu %@, %lu %@", days, NSLocalizedString(@"time_days", @""), hours, NSLocalizedString(@"time_hours", @"")];
	else if (hours)
		return [NSString stringWithFormat:@"%lu %@, %lu %@", hours, NSLocalizedString(@"time_hours", @""), minutes, NSLocalizedString(@"time_minutes", @"")];
	else if (minutes)
		return [NSString stringWithFormat:@"%lu %@, %lu %@", minutes, NSLocalizedString(@"time_minutes", @""), seconds, NSLocalizedString(@"time_seconds", @"")];
	else
		return [NSString stringWithFormat:@"%lu %@", seconds, NSLocalizedString(@"time_seconds", @"")];
}
