module brakk.middleware.base;

import std.stdio;
import brakk.http;

class Middleware
{
	void beforeView(HTTPServerRequest req, HTTPServerResponse res){};
	void afterView(HTTPServerRequest req, HTTPServerResponse res){};
}