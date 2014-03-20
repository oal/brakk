module brakk.middleware.common;

import brakk.http;
import brakk.middleware.base : Middleware;
import brakk.settings : appendSlash;

class CommonMiddleware : Middleware
{
	void beforeView(HTTPServerRequest req, HTTPServerResponse res)
	{
		if(appendSlash && req.path[$-1] != '/') 
		{
			res.redirect(req.path ~ "/");
			return;
		}
	}
}