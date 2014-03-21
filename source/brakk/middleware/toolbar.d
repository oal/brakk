module brakk.middleware.toolbar;

import std.stdio;
import vibe.d;
import brakk.http;
import brakk.middleware.base : Middleware;

class DebugToolbarMiddleware : Middleware
{
	override void afterView(HTTPServerRequest req, HTTPServerResponse res)
	{
		/*res.renderCompat!(
			"debugToolbar.dt"
		)(req);*/
	}
}