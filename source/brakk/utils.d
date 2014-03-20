module brakk.utils;

import std.stdio;
import std.uni;
import std.ascii;
import std.string;
import std.algorithm;
import std.range;
import std.datetime;
import brakk.http;

string slugify(string text)
{
	text = normalize!NFKD(text);
	auto slug = "";
	
	auto lettersAndDigits = letters ~ digits;
	auto whitespace = ['-', ' ', '_'];
	foreach(v; text)
	{
		if(lettersAndDigits.canFind(v))
		{
			slug ~= v;
		}
		else if (whitespace.canFind(v) && slug.back != '-')
		{
			slug ~= '-';
		}
	}
	return slug.toLower();
}

unittest
{
	assert(slugify("Du må ikke sove.") == "du-ma-ikke-sove");
}

enum COLORS : string
{
	CLEAR   = "\x1b[0m",
	BOLD    = "\x1b[1m",
	
	BLACK   = "\x1b[30m",
	RED     = "\x1b[31m",
	GREEN   = "\x1b[32m",
	YELLOW  = "\x1b[33m",
	BLUE    = "\x1b[34m",
	MAGENTA = "\x1b[35m",
	CYAN    = "\x1b[36m",
	WHITE   = "\x1b[37m",
}

void logRequest(HTTPServerRequest req, HTTPServerResponse res)
{
	auto start = Clock.currTime();
	scope(exit)
	{
		auto now = Clock.currTime();
		auto duration = now - start;
		auto color = "";
		auto status = res.statusCode;
		if(status < 299) color = COLORS.GREEN;
		else if(status < 399) color = COLORS.YELLOW;
		else if(status < 499) color = COLORS.RED;
		else color = COLORS.BOLD ~ COLORS.RED;

		writefln(
			color~"[%s] \"%s %s %s\" %s %s"~COLORS.CLEAR,
			now.toString()[0..20],
			req.method,
			req.path,
			req.httpVersion,
			status,
			res.bytesWritten
		);
	}
}