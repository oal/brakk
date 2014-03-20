module brakk.router;

import std.stdio;
import std.array;
import vibe.d : URLRouter, HTTPMethod, HTTPServerRequestDelegate;
import brakk.router;
import brakk.application;
import brakk.http;

class Router : URLRouter
{
	private string[string] urls;

	override URLRouter match(HTTPMethod method, string path, HTTPServerRequestDelegate cb)
	{
		writeln(method, path);
		return super.match(method, path, cb);
	}

	override void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
	{
		super.handleRequest(req, res);
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