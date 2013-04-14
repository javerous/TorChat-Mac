/*
 *  TCParser.cpp
 *
 *  Copyright 2011 Avérous Julien-Pierre
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



#include "TCParser.h"

#include "TCTools.h"
#include "TCInfo.h"



/*
** TCParser - Parsing
*/
#pragma mark -
#pragma mark TCParser - Parsing

// == Give a line to to be parsed to the parser ==
void TCParser::parseLine(const std::string &line)
{
	// Unscape protocol special chars
	std::string *l1 = createReplaceAll(line, "\\n", "\n");
	std::string *l2 = createReplaceAll(*l1, "\\/", "\\");
		
	// Eplode the line with spaces
	std::vector<std::string> *exp = createExplode(*l2, " ");
	
	// Parse the array
	_parseCommand(*exp);
	
	// Free memory
	delete l1;
	delete l2;
	delete exp;	
}



/*
** TCParser - Command
*/
#pragma mark -
#pragma mark TCParser - Command

// -- To be overwritten --
void TCParser::doPing(const std::string &address, const std::string &random)
{
	_parserError(tcrec_cmd_ping, "Ping: Not handled");
}

void TCParser::doPong(const std::string &random)
{
	_parserError(tcrec_cmd_pong, "Pong: Not handled");
}

void TCParser::doStatus(const std::string &status)
{
	_parserError(tcrec_cmd_status, "Status: Not handled");
}

void TCParser::doMessage(const std::string &message)
{
	_parserError(tcrec_cmd_message, "Message: Not handled");
}

void TCParser::doVersion(const std::string &version)
{
	_parserError(tcrec_cmd_version, "Version: Not handled");
}

void TCParser::doProfileText(const std::string &text)
{
	_parserError(tcrec_cmd_profile_text, "Profile Text: Not handled");
}

void TCParser::doProfileName(const std::string &name)
{
	_parserError(tcrec_cmd_profile_name, "Profile Name: Not handled");
}

void TCParser::doProfileAvatar(const std::string &bitmap)
{
	_parserError(tcrec_cmd_profile_avatar, "Profile Avatar: Not handled");
}

void TCParser::doProfileAvatarAlpha(const std::string &bitmap)
{
	_parserError(tcrec_cmd_profile_avatar_alpha, "Profile Avatar Alpha: Not handled");
}

void TCParser::doAddMe()
{
	_parserError(tcrec_cmd_addme, "AddMe:  Not handled");
}

void TCParser::doRemoveMe()
{
	_parserError(tcrec_cmd_removeme, "RemoveMe: Not handled");
}

void TCParser::doFileName(const std::string &uuid, const std::string &fsize, const std::string &bsize, const std::string &filename)
{
	_parserError(tcrec_cmd_filename, "FileName: Not handled");
}

void TCParser::doFileData(const std::string &uuid, const std::string &start, const std::string &hash, const std::string &data)
{
	_parserError(tcrec_cmd_filedata, "FileData: Not handled");
}

void TCParser::doFileDataOk(const std::string &uuid, const std::string &start)
{
	_parserError(tcrec_cmd_filedataok, "FileDataOk: Not handled");
}

void TCParser::doFileDataError(const std::string &uuid, const std::string &start)
{
	_parserError(tcrec_cmd_filedataerror, "FileDataError: Not handled");
}

void TCParser::doFileStopSending(const std::string &uuid)
{
	_parserError(tcrec_cmd_filestopsending, "FileStopSending: Not handled");
}

void TCParser::doFileStopReceiving(const std::string &uuid)
{
	_parserError(tcrec_cmd_filestopreceiving, "FileStopReceiving: Not handled");
}



/*
** TCParser - Error
*/
#pragma mark -
#pragma mark TCParser - Error

void TCParser::parserError(TCInfo *info)
{
	fprintf(stderr, "Unhandled error (%s)\n", info->render().c_str());
}



/*
** TCParser - Parser
*/
#pragma mark -
#pragma mark TCParser - Parser

void TCParser::_parseCommand(std::vector<std::string> &items)
{
	if (items.size() == 0)
        return;
    
    std::string command = items[0];
	
	items.erase(items.begin());
	
    // Dispatch command
    if (command.compare("ping") == 0)
        _parsePing(items);
    else if (command.compare("pong") == 0)
        _parsePong(items);
    else if (command.compare("status") == 0)
        _parseStatus(items);
    else if (command.compare("version") == 0)
        _parseVersion(items);
	else if (command.compare("profile_name") == 0)
        _parseProfileName(items);
	else if (command.compare("profile_text") == 0)
        _parseProfileText(items);
	else if (command.compare("profile_avatar_alpha") == 0)
        _parseProfileAvatarAlpha(items);
	else if (command.compare("profile_avatar") == 0)
        _parseProfileAvatar(items);
	else if (command.compare("message") == 0)
        _parseMessage(items);
	else if (command.compare("add_me") == 0)
        _parseAddMe(items);
	else if (command.compare("remove_me") == 0)
        _parseRemoveMe(items);
	else if (command.compare("filename") == 0)
        _parseFileName(items);
	else if (command.compare("filedata") == 0)
        _parseFileData(items);
	else if (command.compare("filedata_ok") == 0)
        _parseFileDataOk(items);
	else if (command.compare("filedata_error") == 0)
        _parseFileDataError(items);
	else if (command.compare("file_stop_sending") == 0)
        _parseFileStopSending(items);
	else if (command.compare("file_stop_receiving") == 0)
        _parseFileStopReceiving(items);
    else
		_parserError(tcrec_unknown_command, "Unknown command");
}

void TCParser::_parsePing(const std::vector<std::string> &args)
{
	if (args.size() != 2)
    {
		_parserError(tcrec_cmd_ping, "Bad ping argument");
        return;
    }
	
	doPing(args[0], args[1]);
}

void TCParser::_parsePong(const std::vector<std::string> &args)
{
	if (args.size() != 1)
    {
		_parserError(tcrec_cmd_pong, "Bad pong argument");
        return;
	}
	
	doPong(args[0]);
}

void TCParser::_parseStatus(const std::vector<std::string> &args)
{
	if (args.size() != 1)
    {
		_parserError(tcrec_cmd_status, "Bad status argument");
        return;
	}
	
	doStatus(args[0]);
}

void TCParser::_parseVersion(const std::vector<std::string> &args)
{
	if (args.size() != 1)
    {
		_parserError(tcrec_cmd_version, "Bad version argument");
        return;
	}
	
	doVersion(args[0]);
}

void TCParser::_parseProfileText(const std::vector<std::string> &args)
{
	if (args.size() == 0)
    {
		_parserError(tcrec_cmd_profile_text, "Empty profile text");
        return;
	}
	
	std::string *text = createJoin(args, " ");
	
	doProfileText(*text);
	
	delete text;
}

void TCParser::_parseProfileName(const std::vector<std::string> &args)
{
	if (args.size() == 0)
    {
		_parserError(tcrec_cmd_profile_name, "Empty profile name");
        return;
	}
	
	std::string *name = createJoin(args, " ");
	
	doProfileName(*name);
	
	delete name;
}

void TCParser::_parseProfileAvatar(const std::vector<std::string> &args)
{
	if (args.size() == 0)
    {
		_parserError(tcrec_cmd_profile_avatar, "Empty avatar content");
        return;
	}
	
	std::string *bitmap = createJoin(args, " ");
	
	doProfileAvatar(*bitmap);
	
	delete bitmap;
}

void TCParser::_parseProfileAvatarAlpha(const std::vector<std::string> &args)
{
	if (args.size() == 0)
    {
		_parserError(tcrec_cmd_profile_avatar_alpha, "Empty avatar alpha content");
        return;
	}
	
	std::string *bitmap = createJoin(args, " ");
	
	doProfileAvatarAlpha(*bitmap);
	
	delete bitmap;
}

void TCParser::_parseMessage(const std::vector<std::string> &args)
{
	if (args.size() == 0)
    {
		_parserError(tcrec_cmd_message, "Empty message content");
        return;
	}
	
	std::string * msg = createJoin(args, " ");
	
	doMessage(*msg);
	
	delete msg;
}

void TCParser::_parseAddMe(const std::vector<std::string> &args)
{
	doAddMe();
}

void TCParser::_parseRemoveMe(const std::vector<std::string> &args)
{
	doRemoveMe();
}

void TCParser::_parseFileName(const std::vector<std::string> &args)
{
	if (args.size() != 4)
    {
		_parserError(tcrec_cmd_filename, "Bad filename argument");
        return;
	}
	
	doFileName(args[0], args[1], args[2], args[3]);
}

void TCParser::_parseFileData(const std::vector<std::string> &args)
{
	if (args.size() < 4)
    {
		_parserError(tcrec_cmd_filedata, "Bad filedata argument");
		
        return;
	}
	
	std::string *data = createJoin(args, 3, " ");
	
	if (data)
	{
		doFileData(args[0], args[1], args[2], *data);
		
		delete data;
	}
	else
		doFileData(args[0], args[1], args[2], "");
}

void TCParser::_parseFileDataOk(const std::vector<std::string> &args)
{
	if (args.size() != 2)
    {
		_parserError(tcrec_cmd_filedataok, "Bad filedataok argument");
        return;
	}
	
	doFileDataOk(args[0], args[1]);
}

void TCParser::_parseFileDataError(const std::vector<std::string> &args)
{
	if (args.size() != 2)
    {
		_parserError(tcrec_cmd_filedataerror, "Bad filedataerror argument");
        return;
	}

	doFileDataError(args[0], args[1]);
}

void TCParser::_parseFileStopSending(const std::vector<std::string> &args)
{
	if (args.size() != 1)
    {
		_parserError(tcrec_cmd_filestopsending, "Bad filestopsending argument");
        return;
	}
	
	doFileStopSending(args[0]);
}

void TCParser::_parseFileStopReceiving(const std::vector<std::string> &args)
{
	if (args.size() != 1)
    {
		_parserError(tcrec_cmd_filestopreceiving, "Bad filestopreceiving argument");
        return;
	}

	doFileStopReceiving(args[0]);
}


void TCParser::_parserError(tcrec_error error, const char *info)
{
	TCInfo *err = new TCInfo(tcinfo_error, error, info);
	
	parserError(err);
	
	err->release();
}
