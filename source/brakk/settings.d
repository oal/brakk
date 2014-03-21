module brakk.settings;

import brakk.middleware.base : Middleware;
import brakk.middleware.common : CommonMiddleware;
import brakk.middleware.toolbar : DebugToolbarMiddleware;

string baseDir;
bool appendSlash = true;

Middleware[] middlewareClasses;

shared static this()
{
	middlewareClasses ~= new CommonMiddleware();
	middlewareClasses ~= new DebugToolbarMiddleware();
}