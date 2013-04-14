/*
 *  main.m
 *
 *  Copyright 2012 Avrous Julien-Pierre
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



#import "TCChatController.h"

#import <Cocoa/Cocoa.h>



int main(int argc, char *argv[])
{
	// Ignore sigpipe
	signal(SIGPIPE, SIG_IGN);

	// Run
	return NSApplicationMain(argc,  (const char **) argv);
}
