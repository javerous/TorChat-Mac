/*
 *  TCConfigSQLite.m
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

#import <Cocoa/Cocoa.h>
#import <sqlite3.h>

#import "TCConfigSQLite.h"

#import "SMSQLiteCryptoVFS.h"
#import "TCImage.h"

#import "TCFileHelper.h"


/*
** Defines
*/
#pragma mark - Defines

#define TCCONF_KEY_TOR_ADDRESS		@"tor_address"
#define TCCONF_KEY_TOR_PORT			@"tor_socks_port"

#define TCCONF_KEY_IM_ADDRESS		@"im_address"
#define TCCONF_KEY_IM_PORT			@"im_in_port"

#define TCCONF_KEY_MODE				@"mode"

#define TCCONF_KEY_PROFILE_NAME		@"profile_name"
#define TCCONF_KEY_PROFILE_TEXT		@"profile_text"
#define TCCONF_KEY_PROFILE_AVATAR	@"profile_avatar"

#define TCCONF_KEY_UI_TITLE			@"title"

#define TCCONF_KEY_CLIENT_VERSION	@"client_version"
#define TCCONF_KEY_CLIENT_NAME		@"client_name"

// Paths
#define TCCONF_KEY_PATH_TOR_BIN				@"tor_bin"
#define TCCONF_KEY_PATH_TOR_DATA			@"tor_data"
#define TCCONF_KEY_PATH_TOR_IDENTITY		@"tor_identity"
#define TCCONF_KEY_PATH_DOWNLOADS			@"downloads"

#define TCCONF_VALUE_PATH_TYPE_REFERAL		@"<referal>"
#define TCCONF_VALUE_PATH_TYPE_STANDARD		@"<standard>"
#define TCCONF_VALUE_PATH_TYPE_ABSOLUTE		@"<absolute>"



/*
** TCConfigSQLite
*/
#pragma mark - TCConfigSQLite

@implementation TCConfigSQLite
{
	dispatch_queue_t	_localQueue;
	
	NSMutableDictionary *_pathObservers;
	
	NSString			*_dtbPath;
	void				*_dtbPassword;
	const char			*_dtbUUID;
	sqlite3				*_dtb;
	
	sqlite3_stmt		*_stmtInsertSetting;
	sqlite3_stmt		*_stmtSelectSetting;
	sqlite3_stmt		*_stmtDeleteSetting;

	sqlite3_stmt		*_stmtInsertBuddy;
	sqlite3_stmt		*_stmtInsertBuddyProperty;
	sqlite3_stmt		*_stmtSelectBuddyID;
	sqlite3_stmt		*_stmtSelectBuddyAll;
	sqlite3_stmt		*_stmtSelectBuddyProperty;
	sqlite3_stmt		*_stmtDeleteBuddy;
	
	sqlite3_stmt		*_stmtInsertBlocked;
	sqlite3_stmt		*_stmtSelectBlocked;
	sqlite3_stmt		*_stmtDeleteBlocked;
	
	sqlite3_stmt		*_stmtInsertPath;
	sqlite3_stmt		*_stmtSelectPath;
}


/*
** TCConfigSQLite - Instance
*/
#pragma mark - TCConfigSQLite - Instance

+ (void)initialize
{
	if (self == [TCConfigSQLite self])
	{
		SMSQLiteCryptoVFSRegister();
		SMSQLiteCryptoVFSDefaultsSetKeySize(SMCryptoFileKeySize256);
	}
}

- (id)initWithFile:(NSString *)filepath password:(NSString *)password error:(NSError **)error
{
	self = [super init];
	
	if (self)
	{
		// Hold parameters.
		_dtbPath = filepath;
		
		if (!_dtbPath)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:1 userInfo:nil];
			return nil;
		}
		
		// Check parameters.
		if ([[self class] isEncryptedFile:_dtbPath] && password == nil)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:2 userInfo:nil];
			return nil;
		}
		
		// Copy password in 'safe' place.
		if (password)
		{
			vm_size_t hostPageSize = 0;
			
			if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
				hostPageSize = 4096;
			
			if (posix_memalign(&_dtbPassword, hostPageSize, hostPageSize) != 0)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:3 userInfo:nil];
				return nil;
			}
			
			if (mlock(_dtbPassword, hostPageSize) != 0)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:4 userInfo:nil];
				free(_dtbPassword);
				return nil;
			}
			
			strlcpy(_dtbPassword, password.UTF8String, hostPageSize);
			
			// Clean password.
			password = nil;
		}

		// Open database.
		if ([self _openDatabaseWithError:error] == NO)
			return nil;

		// Create queue.
		_localQueue = dispatch_queue_create("com.torchat.app.config-sqlite", DISPATCH_QUEUE_SERIAL);
	}
	
	return self;
}

- (void)dealloc
{
	// Close database.
	[self _closeDatabase];
	
	// Free password.
	if (_dtbPassword)
	{
		vm_size_t hostPageSize = 0;
		
		if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
			hostPageSize = 4096;
		
		memset_s(_dtbPassword, hostPageSize, 0, hostPageSize);
		munlock(_dtbPassword, hostPageSize);
		free(_dtbPassword);
	}
}



/*
** TCConfigSQLite - Tools
*/
#pragma mark - TCConfigSQLite - Tools

+ (BOOL)isEncryptedFile:(NSString *)filepath
{
	return SMCryptoFileCanOpen(filepath.fileSystemRepresentation);
}



/*
** TCConfigSQLite - SQLite
*/
#pragma mark - TCConfigSQLite - SQLite

#pragma mark Instance

- (BOOL)_openDatabaseWithError:(NSError **)error
{
	// > localQueue <
	
#define tc_sqlite3_exec(Database, Sql) do { \
	int __res = sqlite3_exec(Database, Sql, NULL, NULL, NULL);\
	if (__res != SQLITE_OK) {	\
		if (error)				\
			*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(__res) }];\
		return NO;				\
	}							\
} while (0)
	
#define tc_sqlite3_prepare(Dtb, Sql, Stmt) do { \
	int __res = sqlite3_prepare_v2(Dtb, Sql, -1, Stmt, NULL);\
	if (__res != SQLITE_OK) {	\
		if (error)				\
			*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(__res) }];\
		return NO;				\
	}\
} while (0)

	// Open database.
	int result;
	
	if (_dtbPassword)
	{
		const char *uriPath;
		
		_dtbUUID = SMSQLiteCryptoVFSSettingsAdd(_dtbPassword, SMCryptoFileKeySize256);
		uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", _dtbPath, _dtbUUID] UTF8String];
		
		result = sqlite3_open_v2(uriPath, &_dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
		
		if (result != SQLITE_OK)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:5 userInfo:@{ TCConfigSQLiteErrorKey : @(result), TCConfigSMCryptoFileErrorKey : @(SMSQLiteCryptoVFSLastFileCryptoError()) }];
			return NO;
		}
	}
	else
	{
		result = sqlite3_open_v2(_dtbPath.fileSystemRepresentation, &_dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
		
		if (result != SQLITE_OK)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:6 userInfo:@{ TCConfigSQLiteErrorKey : @(result) }];

			return NO;
		}
	}
	
	
	// Pragmas.
	tc_sqlite3_exec(_dtb, "PRAGMA foreign_keys = ON");

	
	// Create 'settings' table.
	// > Table.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS settings (key TEXT NOT NULL, value, UNIQUE (key) ON CONFLICT REPLACE)");

	// > Index.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS settings_idx ON settings(key)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO settings (key, value) VALUES (?, ?)", &_stmtInsertSetting);
	tc_sqlite3_prepare(_dtb, "SELECT value FROM settings WHERE key=? LIMIT 1", &_stmtSelectSetting);
	tc_sqlite3_prepare(_dtb, "DELETE FROM settings WHERE key=? LIMIT 1", &_stmtDeleteSetting);
	
	
	// Create 'buddies' table.
	// > Tables.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS buddies (id INTEGER PRIMARY KEY AUTOINCREMENT, address TEXT NOT NULL, UNIQUE (address) ON CONFLICT ABORT)");
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS buddies_properties (buddy_id INTEGER, key TEXT NOT NULL, value, FOREIGN KEY(buddy_id) REFERENCES buddies(id) ON DELETE CASCADE, UNIQUE (buddy_id, key) ON CONFLICT REPLACE)");
	
	// > Indexes.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS buddies_idx ON buddies(address)");
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS buddies_properties_idx ON buddies_properties(buddy_id, key)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO buddies (address) VALUES (?)", &_stmtInsertBuddy);
	tc_sqlite3_prepare(_dtb, "INSERT INTO buddies_properties (buddy_id, key, value) VALUES (?, ?, ?)", &_stmtInsertBuddyProperty);
	tc_sqlite3_prepare(_dtb, "SELECT id FROM buddies WHERE address=? LIMIT 1", &_stmtSelectBuddyID);
	tc_sqlite3_prepare(_dtb, "SELECT address, key, value FROM buddies LEFT OUTER JOIN buddies_properties ON buddies.id=buddies_properties.buddy_id", &_stmtSelectBuddyAll);
	tc_sqlite3_prepare(_dtb, "SELECT value FROM buddies_properties WHERE buddy_id=? AND key=? LIMIT 1", &_stmtSelectBuddyProperty);
	tc_sqlite3_prepare(_dtb, "DELETE FROM buddies WHERE address=? LIMIT 1", &_stmtDeleteBuddy);
	
	
	// Create 'blocked' table.
	// > Table.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS blocked (address TEXT NOT NULL, UNIQUE (address) ON CONFLICT ABORT)");
	
	// > Indexes.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS blocked_idx ON blocked(address)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO blocked (address) VALUES (?)", &_stmtInsertBlocked);
	tc_sqlite3_prepare(_dtb, "SELECT address FROM blocked LIMIT 1", &_stmtSelectBlocked);
	tc_sqlite3_prepare(_dtb, "DELETE FROM blocked WHERE address=?", &_stmtDeleteBlocked);
	
	// Create 'paths' table.
	// > Table.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS paths (component TEXT NOT NULL, type TEXT NOT NULL, path TEXT, UNIQUE (component) ON CONFLICT REPLACE)");
	
	// > Indexes.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS paths_idx ON paths(component)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO paths (component, type, path) VALUES (?, ?, ?)", &_stmtInsertPath);
	tc_sqlite3_prepare(_dtb, "SELECT type, path FROM paths WHERE component=?", &_stmtSelectPath);
	
	return YES;
}

- (void)_closeDatabase
{
	// > localQueue <
	
#define tc_sqlite3_finalize(Stmt) do { if (Stmt) { sqlite3_reset(Stmt); sqlite3_finalize(Stmt); Stmt = NULL; }  } while (0)
	
	// Finalize statements.
	tc_sqlite3_finalize(_stmtInsertSetting);
	tc_sqlite3_finalize(_stmtSelectSetting);
	tc_sqlite3_finalize(_stmtDeleteSetting);
	
	tc_sqlite3_finalize(_stmtInsertBuddy);
	tc_sqlite3_finalize(_stmtInsertBuddyProperty);
	tc_sqlite3_finalize(_stmtSelectBuddyID);
	tc_sqlite3_finalize(_stmtSelectBuddyAll);
	tc_sqlite3_finalize(_stmtSelectBuddyProperty);
	tc_sqlite3_finalize(_stmtDeleteBuddy);
	
	tc_sqlite3_finalize(_stmtInsertBlocked);
	tc_sqlite3_finalize(_stmtSelectBlocked);
	tc_sqlite3_finalize(_stmtDeleteBlocked);
	
	tc_sqlite3_finalize(_stmtInsertPath);
	tc_sqlite3_finalize(_stmtSelectPath);

	// Close db.
	if (_dtb)
	{
		sqlite3_close(_dtb);
		_dtb = NULL;
	}
	
	// Remove VFS info.
	if (_dtbUUID)
	{
		SMSQLiteCryptoVFSSettingsRemove(_dtbUUID);
		_dtbUUID = NULL;
	}
}


#pragma mark Bridge

- (id)_sqliteValueForStatement:(sqlite3_stmt *)stmt column:(int)column
{
	if (!stmt || !_dtb)
		return nil;
	
	int type = sqlite3_column_type(stmt, column);
	
	switch (type)
	{
		case SQLITE_INTEGER:
		{
			return @(sqlite3_column_int64(stmt, column));
		}
			
		case SQLITE_FLOAT:
		{
			return @(sqlite3_column_double(stmt, column));
		}
			
		case SQLITE_BLOB:
		{
			const void	*data = sqlite3_column_blob(stmt, column);
			int			length = sqlite3_column_bytes(stmt, column);
			
			if (data && length >= 0)
				return [[NSData alloc] initWithBytes:data length:(NSUInteger)length];
			
			break;
		}
			
		case SQLITE_NULL:
		{
			break;
		}
			
		case SQLITE_TEXT:
		{
			const void	*txt = sqlite3_column_text(stmt, column);
			int			length = sqlite3_column_bytes(stmt, column);
			
			if (txt && length >= 0)
				return [[NSString alloc] initWithBytes:txt length:(NSUInteger)length encoding:NSUTF8StringEncoding];
			
			break;
		}
	}
	
	return nil;
}

- (id)_sqliteStepValueForStatement:(sqlite3_stmt *)stmt column:(int)column
{
	// > localQueue <
	
	if (!stmt || !_dtb)
		return nil;
	
	id	obj = nil;
	int	result = sqlite3_step(stmt);

	if (result == SQLITE_ROW)
		obj = [self _sqliteValueForStatement:stmt column:column];
	
	// Reset.
	sqlite3_reset(stmt);
	sqlite3_clear_bindings(stmt);
	
	// Return.
	return obj;
}

- (void)_sqliteStepSetValue:(id)value forStatement:(sqlite3_stmt *)stmt index:(int)index
{
	// > localQueue <
	
	if (!value || !stmt || !_dtb)
		return;

	// Bind.
	if ([value isKindOfClass:[NSString class]])
	{
		NSString *val = value;
		
		sqlite3_bind_text(stmt, index, val.UTF8String, -1, SQLITE_TRANSIENT);
	}
	else if ([value isKindOfClass:[NSNumber class]])
	{
		NSNumber *val = value;
		
		if (strcmp(val.objCType, @encode(float)) == 0 || strcmp(val.objCType, @encode(double)) == 0 || strcmp(val.objCType, @encode(long double)) == 0)
			sqlite3_bind_double(stmt, index, [val doubleValue]);
		else
			sqlite3_bind_int64(stmt, index, [val integerValue]);
	}
	else if ([value isKindOfClass:[NSData class]])
	{
		NSData *val = value;
		
		sqlite3_bind_blob(stmt, index, val.bytes, (int)val.length, SQLITE_TRANSIENT);
	}
	else
	{
		sqlite3_reset(stmt);
		sqlite3_clear_bindings(stmt);
		
		return;
	}
	
	// Exec.
	sqlite3_step(stmt);
	
	// Reset.
	sqlite3_reset(stmt);
	sqlite3_clear_bindings(stmt);
}


#pragma mark Settings

- (id)settingForKey:(NSString *)key
{
	if (!key)
		return nil;
	
	__block id obj = nil;
	
	dispatch_sync(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		sqlite3_bind_text(_stmtSelectSetting, 1, key.UTF8String, -1, SQLITE_TRANSIENT);

		obj = [self _sqliteStepValueForStatement:_stmtSelectSetting column:0];
	});
	
	return obj;
}

- (void)setSetting:(id)value forKey:(NSString *)key
{
	if (!key)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		if (value)
		{
			sqlite3_bind_text(_stmtInsertSetting, 1, key.UTF8String, -1, SQLITE_TRANSIENT);
			
			[self _sqliteStepSetValue:value forStatement:_stmtInsertSetting index:2];
		}
		else
		{
			// Bind.
			sqlite3_bind_text(_stmtDeleteSetting, 1, key.UTF8String, -1, SQLITE_TRANSIENT);
			
			// Exec.
			sqlite3_step(_stmtDeleteSetting);
			
			// Reset.
			sqlite3_reset(_stmtDeleteSetting);
			sqlite3_clear_bindings(_stmtDeleteSetting);
		}
	});
}


#pragma mark Buddies

- (sqlite3_int64)_buddyIDForAddress:(NSString *)address
{
	if (!address || !_dtb)
		return -1;
	
	sqlite3_int64 result = -1;
	
	// Bind.
	sqlite3_bind_text(_stmtSelectBuddyID, 1, address.UTF8String, -1, SQLITE_TRANSIENT);

	// Execute.
	if (sqlite3_step(_stmtSelectBuddyID) == SQLITE_ROW)
		result = sqlite3_column_int64(_stmtSelectBuddyID, 0);
	
	// Reset.
	sqlite3_reset(_stmtSelectBuddyID);
	sqlite3_clear_bindings(_stmtSelectBuddyID);
	
	return result;
}

- (id)_getBuddyProperty:(sqlite3_int64)buddyID key:(NSString *)key
{
	// > localQueue <
	
	if (!key || !_dtb)
		return nil;
	
	sqlite3_bind_int64(_stmtSelectBuddyProperty, 1, buddyID);
	sqlite3_bind_text(_stmtSelectBuddyProperty, 2, key.UTF8String, -1, SQLITE_TRANSIENT);

	return [self _sqliteStepValueForStatement:_stmtSelectBuddyProperty column:0];
}

- (void)_setBuddyProperty:(sqlite3_int64)buddyID key:(NSString *)key value:(id)value
{
	// > localQueue <
	
	if (!_dtb)
		return;
	
	sqlite3_bind_int64(_stmtInsertBuddyProperty, 1, buddyID);
	sqlite3_bind_text(_stmtInsertBuddyProperty, 2, key.UTF8String, -1, SQLITE_TRANSIENT);
		
	[self _sqliteStepSetValue:value forStatement:_stmtInsertBuddyProperty index:3];
}



/*
** TCConfigSQLite - TCConfig
*/
#pragma mark - TCConfigSQLite - TCConfig

#pragma mark Tor

- (NSString *)torAddress
{
	NSString *result = [self settingForKey:TCCONF_KEY_TOR_ADDRESS];
	
	if (result)
		return result;
	
	return @"localhost";
}

- (void)setTorAddress:(NSString *)address
{
	[self setSetting:address forKey:TCCONF_KEY_TOR_ADDRESS];
}

- (uint16_t)torPort
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_TOR_PORT];

	if (result)
		return [result unsignedShortValue];

	return 9050;
}

- (void)setTorPort:(uint16_t)port
{
	[self setSetting:@(port) forKey:TCCONF_KEY_TOR_PORT];
}


#pragma mark TorChat

- (NSString *)selfAddress
{
	NSString *result = [self settingForKey:TCCONF_KEY_IM_ADDRESS];
	
	if (result)
		return result;
	
	return @"xxx";
}

- (void)setSelfAddress:(NSString *)address
{
	[self setSetting:address forKey:TCCONF_KEY_IM_ADDRESS];
}

- (uint16_t)clientPort
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_IM_PORT];
	
	if (result)
		return [result unsignedShortValue];
	
	return 11009;
}

- (void)setClientPort:(uint16_t)port
{
	[self setSetting:@(port) forKey:TCCONF_KEY_IM_PORT];
}


#pragma mark Mode

- (TCConfigMode)mode
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_MODE];
	
	if (result)
	{
		int mode = [result unsignedShortValue];
		
		if (mode == TCConfigModeAdvanced)
			return TCConfigModeAdvanced;
		else if (mode == TCConfigModeBasic)
			return TCConfigModeBasic;
		
		return TCConfigModeAdvanced;
	}
	else
		return TCConfigModeAdvanced;
}

- (void)setMode:(TCConfigMode)mode
{
	[self setSetting:@(mode) forKey:TCCONF_KEY_MODE];
}


#pragma mark Profile

- (NSString *)profileName
{
	NSString *result = [self settingForKey:TCCONF_KEY_PROFILE_NAME];
	
	if (result)
		return result;
	
	return @"-";
}

- (void)setProfileName:(NSString *)name
{
	[self setSetting:name forKey:TCCONF_KEY_PROFILE_NAME];
}

- (NSString *)profileText
{
	NSString *result = [self settingForKey:TCCONF_KEY_PROFILE_TEXT];
	
	if (result)
		return result;
	
	return @"";
}

- (void)setProfileText:(NSString *)text
{
	[self setSetting:text forKey:TCCONF_KEY_PROFILE_TEXT];
}

- (TCImage *)profileAvatar
{
	NSData *result = [self settingForKey:TCCONF_KEY_PROFILE_AVATAR];
	
	if (result)
	{
		NSImage *image = [[NSImage alloc] initWithData:result];
		
		return [[TCImage alloc] initWithImage:image];
	}
	
	return nil;
}

- (void)setProfileAvatar:(TCImage *)picture
{
	if (picture)
	{
		// Get Cocoa image.
		NSImage *image = [picture imageRepresentation];
		
		if (!image)
			return;
		
		// Create PNG representation.
		NSData *tiffData = [image TIFFRepresentation];
		NSData *pngData;
		
		if (!tiffData)
			return;
		
		pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:@{ }];
		
		if (!pngData)
			return;
		
		// Save.
		[self setSetting:pngData forKey:TCCONF_KEY_PROFILE_AVATAR];
	}
	else
	{
		[self setSetting:nil forKey:TCCONF_KEY_PROFILE_AVATAR];
	}
}


#pragma mark Buddies

- (NSArray *)buddies
{
	NSMutableArray *result = [[NSMutableArray alloc] init];
	
	dispatch_sync(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		NSString			*currentAddress = nil;
		NSMutableDictionary	*currentEntry = nil;

		while (sqlite3_step(_stmtSelectBuddyAll) == SQLITE_ROW)
		{
			const char	*address = (const char *)sqlite3_column_text(_stmtSelectBuddyAll, 0);
			const char	*key = (const char *)sqlite3_column_text(_stmtSelectBuddyAll, 1);
			id			value = [self _sqliteValueForStatement:_stmtSelectBuddyAll column:2];
			
			if (!address)
				continue;
			
			if ([currentAddress isEqualToString:@(address)] == NO)
			{
				currentEntry = [[NSMutableDictionary alloc] init];
				currentAddress = @(address);
				
				currentEntry[TCConfigBuddyAddress] = currentAddress;
				
				[result addObject:currentEntry];
			}
			
			if (key && value)
				currentEntry[@(key)] = value;
		}
		
		sqlite3_reset(_stmtSelectBuddyAll);
	});
	
	return result;
}

- (void)addBuddy:(NSString *)address alias:(NSString *)alias notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
	if (!notes)
		notes = @"";
	
	dispatch_async(_localQueue, ^{

		if (!_dtb)
			return;
		
		int result;

		// Bind.
		sqlite3_bind_text(_stmtInsertBuddy, 1, address.UTF8String, -1, SQLITE_TRANSIENT);
		
		// Execute
		result = sqlite3_step(_stmtInsertBuddy);
		
		// Reset.
		sqlite3_reset(_stmtInsertBuddy);
		
		if (result == SQLITE_DONE)
		{
			sqlite3_int64 buddyID = sqlite3_last_insert_rowid(_dtb);
			
			[self _setBuddyProperty:buddyID key:TCConfigBuddyAlias value:alias];
			[self _setBuddyProperty:buddyID key:TCConfigBuddyNotes value:notes];
		}
	});
}

- (void)removeBuddy:(NSString *)address
{
	if (!address)
		return;
	
	dispatch_async(_localQueue, ^{

		if (!_dtb)
			return;
		
		// Bind.
		sqlite3_bind_text(_stmtDeleteBuddy, 1, address.UTF8String, -1, SQLITE_TRANSIENT);

		// Execute
		sqlite3_step(_stmtDeleteBuddy);
		
		// Reset.
		sqlite3_reset(_stmtDeleteBuddy);
	});
}

- (void)setBuddy:(NSString *)address alias:(NSString *)alias
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyAlias value:alias];
	});
}

- (void)setBuddy:(NSString *)address notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!notes)
		notes = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyNotes value:notes];
	});
}

- (void)setBuddy:(NSString *)address lastProfileName:(NSString *)lastName
{
	if (!address)
		return;
	
	if (!lastName)
		lastName = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastName value:lastName];
	});
}

- (void)setBuddy:(NSString *)address lastProfileText:(NSString *)lastText
{
	if (!address)
		return;
	
	if (!lastText)
		lastText = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastText value:lastText];
	});
}

- (void)setBuddy:(NSString *)address lastProfileAvatar:(TCImage *)lastAvatar
{
	if (!address || !lastAvatar)
		return;
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		// Create PNG representation.
		NSImage *image = [lastAvatar imageRepresentation];
		NSData	*tiffData = [image TIFFRepresentation];
		NSData	*pngData;
		
		if (!tiffData)
			return;
		
		pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:@{ }];
		
		if (!pngData)
			return;
		
		// Save
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastAvatar value:pngData];
	});
}

- (NSString *)getBuddyAlias:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyAlias];
	});
	
	return result;
}

- (NSString *)getBuddyNotes:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyNotes];
	});
	
	return result;
}

- (NSString *)getBuddyLastProfileName:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastName];
	});
	
	return result;
}

- (NSString *)getBuddyLastProfileText:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastText];
	});
	
	return result;
}

- (TCImage *)getBuddyLastProfileAvatar:(NSString *)address
{
	if (!address)
		return nil;
	
	__block TCImage *result;
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		NSData	*data = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastAvatar];
		NSImage *image = [[NSImage alloc] initWithData:data];
		
		result = [[TCImage alloc] initWithImage:image];
	});
	
	return result;
}


#pragma mark Blocked

- (NSArray *)blockedBuddies
{
	NSMutableArray *result = [[NSMutableArray alloc] init];
	
	dispatch_sync(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		while (sqlite3_step(_stmtSelectBlocked) == SQLITE_ROW)
		{
			const char *address = (const char *)sqlite3_column_text(_stmtSelectBlocked, 0);
			
			if (address)
				[result addObject:@(address)];
		}
		
		sqlite3_reset(_stmtSelectBlocked);
	});
	
	return result;
}

- (void)addBlockedBuddy:(NSString *)address
{
	if (!address)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		// Bind.
		sqlite3_bind_text(_stmtInsertBlocked, 1, address.UTF8String, -1, SQLITE_TRANSIENT);

		// Execute.
		sqlite3_step(_stmtInsertBlocked);
		
		// Reset.
		sqlite3_reset(_stmtInsertBlocked);
	});
}

- (void)removeBlockedBuddy:(NSString *)address
{
	dispatch_async(_localQueue, ^{

		if (!_dtb)
			return;
		
		// Bind.
		sqlite3_bind_text(_stmtDeleteBlocked, 1, address.UTF8String, -1, SQLITE_TRANSIENT);
		
		// Execute.
		sqlite3_step(_stmtDeleteBlocked);
		
		// Reset.
		sqlite3_reset(_stmtDeleteBlocked);
	});
}


#pragma mark UI

- (TCConfigTitle)modeTitle
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_UI_TITLE];
	
	if (!result)
		return TCConfigTitleAddress;
	
	return (TCConfigTitle)[result unsignedShortValue];
}

- (void)setModeTitle:(TCConfigTitle)mode
{
	[self setSetting:@(mode) forKey:TCCONF_KEY_UI_TITLE];
}


#pragma mark Client

- (NSString *)clientVersion:(TCConfigGet)get
{
	switch (get)
	{
		case TCConfigGetDefault:
		{
			NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			
			if (version)
				return version;
			
			return @"";
		}
			
		case TCConfigGetDefined:
		{
			NSString *value = [self settingForKey:TCCONF_KEY_CLIENT_VERSION];
			
			if (value)
				return value;
			
			return @"";
		}
			
		case TCConfigGetReal:
		{
			NSString *value = [self clientVersion:TCConfigGetDefined];
			
			if ([value length] == 0)
				value = [self clientVersion:TCConfigGetDefault];
			
			return value;
		}
	}
	
	return @"";
}

- (void)setClientVersion:(NSString *)version
{
	if (!version)
		return;
	
	[self setSetting:version forKey:TCCONF_KEY_CLIENT_VERSION];
}

- (NSString *)clientName:(TCConfigGet)get
{
	switch (get)
	{
		case TCConfigGetDefault:
		{
			return @"TorChat for Mac";
		}
			
		case TCConfigGetDefined:
		{
			NSString *value = [self settingForKey:TCCONF_KEY_CLIENT_NAME];
			
			if (value)
				return value;
			
			return @"";
		}
			
		case TCConfigGetReal:
		{
			NSString *value = [self clientName:TCConfigGetDefined];
			
			if ([value length] == 0)
				value = [self clientName:TCConfigGetDefault];
			
			return value;
		}
	}
	
	return @"";
}

- (void)setClientName:(NSString *)name
{
	if (!name)
		return;
	
	[self setSetting:name forKey:TCCONF_KEY_CLIENT_NAME];
}


#pragma mark Paths

- (void)setPathForComponent:(TCConfigPathComponent)component pathType:(TCConfigPathType)pathType path:(NSString *)path
{
	dispatch_async(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		// Handle special referal component.
		if (component == TCConfigPathComponentReferal)
		{
			if (!path)
				return;
			
			// Check parameter.
			BOOL isDirectory = NO;
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory == NO)
				return;
			
			// Prepare move.
			NSString *configFileName = [_dtbPath lastPathComponent];
			NSString *newPath = [path stringByAppendingPathComponent:configFileName];
			
			[self _closeDatabase];
			
			// Move.
			if ([[NSFileManager defaultManager] moveItemAtPath:_dtbPath toPath:newPath error:nil] == NO)
			{
				[self _openDatabaseWithError:nil]; // re-open.
				return;
			}
			
			// Hold new path.
			_dtbPath = newPath;
			
			// Re-open on new path.
			[self _openDatabaseWithError:nil];
			
			// Notify this component.
			[self _notifyPathChangeForComponent:TCConfigPathComponentReferal];
			
			// Notify components using this component.
			[self componentsEnumerateWithBlock:^(TCConfigPathComponent aComponent) {
				if ([self _pathTypeForComponent:aComponent] == TCConfigPathTypeReferal)
					[self _notifyPathChangeForComponent:aComponent];
			}];
		}
		else
		{
			NSString *componentStr = [self componentNameForComponent:component];
			NSString *pathTypeStr = [self pathTypeNameForPathType:pathType];
			
			// Bind.
			sqlite3_bind_text(_stmtInsertPath, 1, componentStr.UTF8String, -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(_stmtInsertPath, 2, pathTypeStr.UTF8String, -1, SQLITE_TRANSIENT);
			
			if (path)
				sqlite3_bind_text(_stmtInsertPath, 3, path.UTF8String, -1, SQLITE_TRANSIENT);
			else
				sqlite3_bind_null(_stmtInsertPath, 3);

			// Execute.
			sqlite3_step(_stmtInsertPath);
			
			// Reset.
			sqlite3_clear_bindings(_stmtInsertPath);
			sqlite3_reset(_stmtInsertPath);

			
			// Notify.
			[self _notifyPathChangeForComponent:component];
		}
	});
}

- (NSString *)pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _pathForComponent:component fullPath:fullPath];
	});
	
	return result;
}

- (NSString *)_pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath
{
	// > localQueue <
	
	if (!_dtb)
		return nil;
	
	// Get default subpath.
	NSString	*standardSubPath = nil;
	NSString	*referalSubPath = nil;
	
	switch (component)
	{
		case TCConfigPathComponentReferal:
		{
			if (fullPath)
				return [_dtbPath stringByDeletingLastPathComponent];
			else
				return nil;
		}
			
		case TCConfigPathComponentTorBinary:
		{
			standardSubPath = @"/TorChat/Tor/";
			referalSubPath = @"/tor/bin/";
			break;
		}
			
		case TCConfigPathComponentTorData:
		{
			standardSubPath = @"/TorChat/TorData/";
			referalSubPath = @"/tor/data/";
			break;
		}
			
		case TCConfigPathComponentTorIdentity:
		{
			standardSubPath = @"/TorChat/TorIdentity/";
			referalSubPath = @"/tor/identity/";
			break;
		}
			
		case TCConfigPathComponentDownloads:
		{
			standardSubPath = @"/TorChat/";
			referalSubPath = @"/Downloads/";
			break;
		}
	}
	
	// Get component key.
	NSString *componentStr = [self componentNameForComponent:component];
	
	if (!componentStr)
		return nil;
	
	// Get component config.
	NSString *componentPathTypeStr = nil;
	NSString *componentPath = nil;

	// > Bind.
	sqlite3_bind_text(_stmtSelectPath, 1, componentStr.UTF8String, -1, SQLITE_TRANSIENT);
	
	// > Execute.
	if (sqlite3_step(_stmtSelectPath) == SQLITE_ROW)
	{
		const char *type = (const char *)sqlite3_column_text(_stmtSelectPath, 0);
		const char *path = (const char *)sqlite3_column_text(_stmtSelectPath, 1);

		if (type)
			componentPathTypeStr = @(type);
		
		if (path)
			componentPath = @(path);
	}
	
	// > Reset.
	sqlite3_reset(_stmtSelectPath);
	
	// Convert component config.
	TCConfigPathType componentPathType = [self pathTypeForPathTypeName:componentPathTypeStr];

	// Compose path according to path type.
	switch (componentPathType)
	{
		case TCConfigPathTypeReferal:
		{
			// > Get subpath.
			NSString *subPath;
			
			if (componentPath)
				subPath = componentPath;
			else
				subPath = referalSubPath;
			
			// > Compose path.
			if (fullPath)
			{
				NSString *path = [self _pathForComponent:TCConfigPathComponentReferal fullPath:YES];
				
				return [[path stringByAppendingPathComponent:subPath] stringByStandardizingPath];
			}
			else
				return subPath;
		}
			
		case TCConfigPathTypeStandard:
		{
			// > Compose path.
			if (fullPath)
			{
				// >> Get standard path directory.
				NSSearchPathDirectory standardPathDirectory;
				
				switch (component)
				{
					case TCConfigPathComponentReferal	: return nil; // never called.
					case TCConfigPathComponentTorBinary	: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentTorData	: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentTorIdentity: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentDownloads	: standardPathDirectory = NSDownloadsDirectory;	break;
				}
				
				// >> Get URL of the standard path directory.
				NSURL *url = [[NSFileManager defaultManager] URLForDirectory:standardPathDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
				
				if (!url)
					return nil;
				
				// >> Create full path.
				url = [url URLByAppendingPathComponent:standardSubPath isDirectory:YES];
				
				if (!url)
					return nil;
				
				return [[url path] stringByStandardizingPath];
			}
			else
				return standardSubPath;
		}
			
		case TCConfigPathTypeAbsolute:
		{
			if (fullPath)
				return [componentPath stringByStandardizingPath];
			else
				return componentPath;
		}
	}
	
	return nil;
}

#pragma mark > Type

- (TCConfigPathType)pathTypeForComponent:(TCConfigPathComponent)component
{
	__block TCConfigPathType result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _pathTypeForComponent:component];
	});
	
	return result;
}

- (TCConfigPathType)_pathTypeForComponent:(TCConfigPathComponent)component
{
	// > localQueue <
	
	if (!_dtb)
		return TCConfigPathTypeReferal;
	
	NSString *componentStr = [self componentNameForComponent:component];
	
	if (!componentStr)
		return TCConfigPathTypeReferal;
	
	// Get component config.
	NSString *componentPathTypeStr = nil;
	
	// > Bind.
	sqlite3_bind_text(_stmtSelectPath, 1, componentStr.UTF8String, -1, SQLITE_TRANSIENT);
	
	// > Execute.
	if (sqlite3_step(_stmtSelectPath) == SQLITE_ROW)
	{
		const char *type = (const char *)sqlite3_column_text(_stmtSelectPath, 0);
		
		if (type)
			componentPathTypeStr = @(type);
	}
	
	// > Reset.
	sqlite3_reset(_stmtSelectPath);
	
	// Convert component config.
	return [self pathTypeForPathTypeName:componentPathTypeStr];
}

- (TCConfigPathType)pathTypeForPathTypeName:(NSString *)pathTypeName
{
	if ([pathTypeName isEqualToString:TCCONF_VALUE_PATH_TYPE_REFERAL])
		return TCConfigPathTypeReferal;
	else if ([pathTypeName isEqualToString:TCCONF_VALUE_PATH_TYPE_STANDARD])
		return TCConfigPathTypeStandard;
	else if ([pathTypeName isEqualToString:TCCONF_VALUE_PATH_TYPE_ABSOLUTE])
		return TCConfigPathTypeAbsolute;
	
	return TCConfigPathTypeReferal;
}

- (NSString *)pathTypeNameForPathType:(TCConfigPathType)pathType
{
	switch (pathType)
	{
		case TCConfigPathTypeReferal:
			return TCCONF_VALUE_PATH_TYPE_REFERAL;
			
		case TCConfigPathTypeStandard:
			return TCCONF_VALUE_PATH_TYPE_STANDARD;
			
		case TCConfigPathTypeAbsolute:
			return TCCONF_VALUE_PATH_TYPE_ABSOLUTE;
	}
	
	return nil;
}

#pragma mark > Component

- (NSString *)componentNameForComponent:(TCConfigPathComponent)component
{
	switch (component)
	{
		case TCConfigPathComponentReferal:
			return nil;
			
		case TCConfigPathComponentTorBinary:
			return TCCONF_KEY_PATH_TOR_BIN;
			
		case TCConfigPathComponentTorData:
			return TCCONF_KEY_PATH_TOR_DATA;
			
		case TCConfigPathComponentTorIdentity:
			return TCCONF_KEY_PATH_TOR_IDENTITY;
			
		case TCConfigPathComponentDownloads:
			return TCCONF_KEY_PATH_DOWNLOADS;
	}
	
	return nil;
}

- (void)componentsEnumerateWithBlock:(void (^)(TCConfigPathComponent component))block
{
	block(TCConfigPathComponentTorBinary);
	block(TCConfigPathComponentTorData);
	block(TCConfigPathComponentTorIdentity);
	block(TCConfigPathComponentDownloads);
}

#pragma mark > Observers

- (id)addPathObserverForComponent:(TCConfigPathComponent)component queue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block
{
	// Check parameters.
	if (!block)
		return nil;
	
	if (!queue)
		queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	// Create result object.
	NSDictionary *result = @{ @"component" : @(component), @"queue" : queue, @"block" : block };
	
	// Add to observers.
	dispatch_barrier_async(_localQueue, ^{
		
		// > Create master observers.
		if (!_pathObservers)
			_pathObservers = [[NSMutableDictionary alloc] init];
		
		// > Get observers for this component.
		NSMutableArray *observers = _pathObservers[@(component)];
		
		if (!observers)
		{
			observers = [[NSMutableArray alloc] init];
			_pathObservers[@(component)] = observers;
		}
		
		// > Add this observer to the list.
		[observers addObject:result];
	});
	
	return result;
}

- (void)removePathObserver:(id)observer
{
	if (!observer)
		return;
	
	NSDictionary	*info = observer;
	NSNumber		*component = info[@"component"];
	
	dispatch_barrier_async(_localQueue, ^{
		
		NSMutableArray *array = _pathObservers[component];
		
		[array removeObjectIdenticalTo:info];
	});
}

- (void)_notifyPathChangeForComponent:(TCConfigPathComponent)component
{
	// > localQueue <
	
	// Get observers for this component.
	NSArray *observers = _pathObservers[@(component)];
	
	if (!observers)
		return;
	
	// Notify each observers.
	for (NSDictionary *observer in observers)
	{
		dispatch_block_t block = observer[@"block"];
		dispatch_queue_t queue = observer[@"queue"];
		
		dispatch_async(queue, ^{
			block();
		});
	}
}


#pragma mark Strings

- (NSString *)localizedString:(TCConfigStringItem)stringItem
{
	switch (stringItem)
	{
		case TCConfigStringItemMyselfBuddy:
			return NSLocalizedString(@"core_mng_myself", @"");
	}
	
	return nil;
}


#pragma mark Synchronize

- (void)synchronize
{
	dispatch_sync(_localQueue, ^{ });
}

- (void)close
{
	dispatch_sync(_localQueue, ^{
		[self _closeDatabase];
	});
}



/*
** TCConfigSQLite - TCConfigEncryptable
*/
#pragma mark - TCConfigSQLite - TCConfigEncryptable

- (BOOL)isEncrypted
{
	__block BOOL result = NO;
	
	dispatch_sync(_localQueue, ^{
		result = (_dtbPassword != NULL);
	});
	
	return result;
}

- (void)changePassword:(NSString *)newPassword completionHandler:(void (^)(NSError *error))handler
{
	if (!handler)
		handler = ^(NSError *error) { };
	
	dispatch_async(_localQueue, ^{
		
		dispatch_queue_t	queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		NSError				*error = nil;
		
		if ([self _changePassword:newPassword error:&error])
		{
			dispatch_async(queue, ^{
				handler(nil);
			});
		}
		else
		{
			dispatch_async(queue, ^{
				handler(error);
			});
		}
	});
}

- (BOOL)_changePassword:(NSString *)newPassword error:(NSError **)error
{
	// > localQueue <
	
	if (!_dtb)
		return NO;
	
	if (_dtbPassword)
	{
		// Is encrypted + new password : change password.
		if (newPassword)
		{
			SMCryptoFileError	smError;
			BOOL				result;
			
			result = SMSQLiteCryptoVFSChangePassword(_dtb, newPassword.UTF8String, &smError);
			
			if (result == NO)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSMCryptoFileErrorKey : @(smError) }];
			
			return result;
		}
		
		// Is encrypted + no new password  : deactivate encryption.
		else
		{
			NSFileManager	*mng = [NSFileManager defaultManager];
			NSString		*tpath = [_dtbPath stringByAppendingString:@"-tmp"];
			int				sres;
			
			sqlite3			*ndtb = NULL;
			sqlite3			*odtb = NULL;
			void			*odtbPassword = NULL;
			const char		*odtbUUID = NULL;
			
			sqlite3_backup	*backup = NULL;
			
			// Close database.
			[self _closeDatabase];
			
			// Move encrypted database to tmp base.
			if ([mng moveItemAtPath:_dtbPath toPath:tpath error:error] == NO)
				goto errDec;
			
			// Open encrypted moved database.
			const char *uriPath;
			
			odtbUUID = SMSQLiteCryptoVFSSettingsAdd(_dtbPassword, SMCryptoFileKeySize256);
			uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", tpath, odtbUUID] UTF8String];
			
			sres = sqlite3_open_v2(uriPath, &odtb, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
			
			if (sres != SQLITE_OK)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres), TCConfigSMCryptoFileErrorKey : @(SMSQLiteCryptoVFSLastFileCryptoError()) }];
				goto errDec;
			}
			
			sqlite3_exec(odtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			// Open new clear database.
			sres = sqlite3_open_v2(_dtbPath.fileSystemRepresentation, &ndtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
			
			if (sres != SQLITE_OK)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errDec;
			}
			
			sqlite3_exec(ndtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			
			// Create backup.
			backup = sqlite3_backup_init(ndtb, "main", odtb, "main");
			
			if (!backup)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't create backup object" }];
				goto errDec;
			}
			
			// Backup.
			sres = sqlite3_backup_step(backup, -1);
			
			if (sres != SQLITE_DONE)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errDec;
			}
			
			sqlite3_backup_finish(backup);
			backup = NULL;
			
			// Close databases.
			sqlite3_close(odtb);
			sqlite3_close(ndtb);
			
			odtb = NULL;
			ndtb = NULL;
			
			// Free UUID.
			SMSQLiteCryptoVFSSettingsRemove(odtbUUID);
			odtbUUID = NULL;
			
			// Move crypto info.
			odtbPassword = _dtbPassword;
			_dtbPassword = NULL;
			
			// Re-open database.
			if ([self _openDatabaseWithError:error] == NO)
				goto errDec;
			
			// Free password.
			vm_size_t hostPageSize = 0;
			
			if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
				hostPageSize = 4096;
			
			memset_s(odtbPassword, hostPageSize, 0, hostPageSize);
			munlock(odtbPassword, hostPageSize);
			free(odtbPassword);
			
			odtbPassword = NULL;
			
			// Remove old file.
			[mng removeItemAtPath:tpath error:error];
			
			// Everything is ok.
			return YES;
			
		errDec:
			
			if (backup)
				sqlite3_backup_finish(backup);
			
			// Close new)database.
			if (ndtb)
				sqlite3_close(ndtb);
			
			// Close old-database.
			if (odtb)
				sqlite3_close(odtb);
			
			// Remove crypto setting.
			if (odtbUUID)
			{
				SMSQLiteCryptoVFSSettingsRemove(odtbUUID);
				odtbUUID = NULL;
			}
			
			// Move back database.
			if ([mng fileExistsAtPath:tpath] && [mng fileExistsAtPath:_dtbPath])
			{
				[mng removeItemAtPath:_dtbPath error:nil];
				[mng moveItemAtPath:tpath toPath:_dtbPath error:nil];
			}
			
			// Re-set password.
			if (odtbPassword)
				_dtbPassword = odtbPassword;
			
			// Re-open database.
			if (!_dtb)
				[self _openDatabaseWithError:nil];
			
			return NO;
		}
	}
	else
	{
		// Is not encrypted + new password : activate encryption.
		if (newPassword)
		{
			NSFileManager	*mng = [NSFileManager defaultManager];
			NSString		*tpath = [_dtbPath stringByAppendingString:@"-tmp"];
			int				sres;
			
			void		*ndtbPassword = NULL;
			const char	*ndtbUUID = NULL;
			sqlite3		*ndtb = NULL;
			sqlite3		*odtb = NULL;
			
			sqlite3_backup *backup = NULL;
			
			// Copy password.
			vm_size_t hostPageSize = 0;
			
			if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
				hostPageSize = 4096;
			
			if (posix_memalign(&ndtbPassword, hostPageSize, hostPageSize) != 0)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't allocate password buffer" }];
				goto errEnc;
			}
			
			if (mlock(ndtbPassword, hostPageSize) != 0)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't mlock password buffer" }];
				goto errEnc;
			}
			
			strlcpy(ndtbPassword, newPassword.UTF8String, hostPageSize);
			
			// Close database.
			[self _closeDatabase];
			
			// Move clear database to tmp base.
			if ([mng moveItemAtPath:_dtbPath toPath:tpath error:error] == NO)
				goto errEnc;
			
			// Open moved clear database.
			sres = sqlite3_open_v2(tpath.fileSystemRepresentation, &odtb, SQLITE_OPEN_READONLY, NULL);
			
			if (sres != SQLITE_OK)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errEnc;
			}
			
			sqlite3_exec(odtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			
			// Open new encrypted database.
			const char *uriPath;
			
			ndtbUUID = SMSQLiteCryptoVFSSettingsAdd(ndtbPassword, SMCryptoFileKeySize256);
			uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", _dtbPath, ndtbUUID] UTF8String];
			
			sres = sqlite3_open_v2(uriPath, &ndtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
			
			if (sres != SQLITE_OK)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres), TCConfigSMCryptoFileErrorKey : @(SMSQLiteCryptoVFSLastFileCryptoError()) }];
				goto errEnc;
			}
			
			sqlite3_exec(ndtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			// Create backup.
			backup = sqlite3_backup_init(ndtb, "main", odtb, "main");
			
			if (!backup)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't create backup object" }];
				goto errEnc;
			}
			
			// Backup.
			sres = sqlite3_backup_step(backup, -1);
			
			if (sres != SQLITE_DONE)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errEnc;
			}
			
			sqlite3_backup_finish(backup);
			backup = NULL;
			
			// Close databases.
			sqlite3_close(odtb);
			sqlite3_close(ndtb);
			
			odtb = NULL;
			ndtb = NULL;
			
			// Hold crypto info.
			_dtbPassword = ndtbPassword;
			_dtbUUID = ndtbUUID;
			
			// Re-open database.
			if ([self _openDatabaseWithError:error] == NO)
				goto errEnc;
			
			// Remove old clear file.
			TCFileSecureRemove(tpath);
			
			// Everything is ok.
			return YES;
			
		errEnc:
			
			// Free backup.
			if (backup)
				sqlite3_backup_finish(backup);
			
			// Close new-database.
			if (ndtb)
				sqlite3_close(ndtb);
			
			// Close old-database.
			if (odtb)
				sqlite3_close(odtb);
			
			// Free new-password.
			if (ndtbPassword)
			{
				memset_s(ndtbPassword, hostPageSize, 0, hostPageSize);
				munlock(ndtbPassword, hostPageSize);
				free(ndtbPassword);
				
				_dtbPassword = NULL;
			}
			
			// Remove new-setting.
			if (ndtbUUID)
			{
				SMSQLiteCryptoVFSSettingsRemove(ndtbUUID);
				_dtbUUID = NULL;
			}
			
			// Move back database.
			if ([mng fileExistsAtPath:tpath] && [mng fileExistsAtPath:_dtbPath])
			{
				[mng removeItemAtPath:_dtbPath error:nil];
				[mng moveItemAtPath:tpath toPath:_dtbPath error:nil];
			}
			
			// Re-open database.
			if (!_dtb)
				[self _openDatabaseWithError:nil];
			
			return NO;
		}
		
		// Is not encrypted + no new password : nop.
		else
		{
			// Nothing to do.
			return YES;
		}
	}
}

@end
