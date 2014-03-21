module brakk.project;

import std.stdio;
import std.path;
import std.array;
import vibe.d;
import brakk.application;
import brakk.router;
import brakk.http;
import brakk.middleware.base;
import brakk.settings;
import brakk.debugtools;
import brakk.templates;

class Project
{
	private Application[] appClasses;
	private Router router;
	private Middleware[] middlewareClasses;

	this(string moduleName = __MODULE__)
	{
		if(!baseDir) baseDir = join(absolutePath(moduleName).split(dirSeparator)[0..$-1], dirSeparator);
	}

	void applications(Application[] classes)
	{
		appClasses ~= classes;
	}

	void middleware(Middleware[] classes)
	{
		middlewareClasses ~= classes;
	}

	private Router setupRouter()
	{
		router = new Router();
		foreach(app; appClasses)
		{
			router.addApplication(app);
		}

		debug serveDebugFiles(router);

		return router;
	}

	void run()
	{
		router = setupRouter();

		auto settings = new HTTPServerSettings;
		settings.port = 8080;
		settings.bindAddresses = ["::1", "127.0.0.1"];
		settings.errorPageHandler = toDelegate(&errorPage);
		listenHTTP(settings, router);
		
		logInfo("Please open http://127.0.0.1:8080/ in your browser.");
	}
}