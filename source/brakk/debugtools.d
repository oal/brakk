module brakk.debugtools;

import std.stdio;
import std.path;
import std.string;
import std.array;
import vibe.d : serveStaticFiles;
import brakk.settings;
import brakk.router : Router;

struct SourceLines
{
	int start;
	string[] lines;
	ulong highlight;
}

SourceLines exceptionSource(Throwable exception, int lineOffset)
{
	immutable relFile = exception.file.replace(".", std.path.dirSeparator);
	immutable sourceFile = buildPath(baseDir, "source", relFile~".d");

	SourceLines sourceLines;
	sourceLines.start = cast(int)exception.line - lineOffset;
	sourceLines.highlight = exception.line;

	File f;
	try f = File(sourceFile, "r");
	catch return sourceLines;

	scope(exit) f.close();
	auto line = 0;
	while(!f.eof && line < exception.line + lineOffset)
	{
		line++;
		if(line < exception.line - lineOffset)
		{
			f.readln();
			continue;
		}
		sourceLines.lines ~= f.readln().stripRight();
	}

	return sourceLines;
}

void serveDebugFiles(Router router)
{
	auto publicPath = __FILE__.split(dirSeparator)[0..$-3].join(dirSeparator) ~ dirSeparator ~ "public";
	router.serveStatic("/__debug__/", publicPath);
}