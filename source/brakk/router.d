module brakk.router;

import std.stdio;
import std.array;
import std.algorithm : startsWith;
import vibe.d : URLRouter, HTTPMethod, HTTPServerRequestDelegate, serveStaticFiles;
import brakk.router;
import brakk.application;
import brakk.http;
import brakk.settings;

class Router : URLRouter
{
	private string[] staticDirectories;
	private string[string] urls;

	override URLRouter match(HTTPMethod method, string path, HTTPServerRequestDelegate cb)
	{
		writeln(method, path);
		return super.match(method, path, cb);
	}

	override void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
	{
		bool runMiddleware = true;
		foreach(dir; staticDirectories)
		{
			if(req.path.startsWith(dir)) runMiddleware = false; break;
		}

		if(runMiddleware) foreach(middleware; middlewareClasses) middleware.beforeView(req, res);
		super.handleRequest(req, res);
		if(runMiddleware) foreach(middleware; middlewareClasses) middleware.afterView(req, res);
	}

	void addApplication(Application app)
	{
		auto basePath = app.getPrefix();
		foreach(view; app.getViews())
		{
			writeln(view.url);
			urls[app.getName() ~ ":" ~ view.name] = view.url;
			any(view.url, view);
		}
	}

	void serveStatic(string directory, string path)
	{
		staticDirectories ~= directory;
		get(directory~"*", serveStaticFiles(path));
	}

	string formatURL(string name, string[] args)
	{
		auto pattern = urls[name];
		string url;
		auto isArg = false;
		for(int i=0; i < pattern.length; i++)
		{
			auto val = pattern[i];
			if(!isArg && val != ':')
			{
				url ~= val;
			}
			else if(val == ':')
			{
				url ~= args.front;
				args.popFront();
				isArg = true;
			}
			else if(isArg && val == '/')
			{
				url ~= val;
				isArg = false;
			}
		}
		
		return url;
	}
}