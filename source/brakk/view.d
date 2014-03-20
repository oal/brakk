module brakk.view;

import std.stdio;
import std.string;
import std.datetime;
import vibe.d : HTTPServerRequestHandler, HTTPMethod;
import brakk.http;
import brakk.utils;

class View : HTTPServerRequestHandler
{
	const string name;
	package string url;

	this()
	{
		name = this.classinfo.name.split(".")[$-1];
	}

	void setURL(string url)
	{
		this.url = url;
	}

	void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
	{
		switch(req.method)
		{
			default: throw new Exception("Unknown HTTP method");
			case HTTPMethod.GET: 
				get(req, res); break;
			case HTTPMethod.POST:
				post(req, res); break;
			case HTTPMethod.PUT:
				put(req, res); break;
			case HTTPMethod.HEAD: 
				head(req, res); break;
		}

		debug logRequest(req, res);
	}
	
	void get(HTTPServerRequest req, HTTPServerResponse res){}
	void post(HTTPServerRequest req, HTTPServerResponse res){}
	void put(HTTPServerRequest req, HTTPServerResponse res){}
	void head(HTTPServerRequest req, HTTPServerResponse res){}
}