module brakk.http;

import std.stdio;
import std.datetime;
import vibe.d;
public import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import brakk.utils;
import brakk.debugtools;

void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error)
{
	auto sourceLines = exceptionSource(error.exception, 10);
	auto serverTime = Clock.currTime;

	res.renderCompat!(
		"error.dt",
		HTTPServerRequest, "req",
		HTTPServerErrorInfo, "error",
		SourceLines, "sourceLines",
		SysTime, "serverTime"
	)(req, error, sourceLines, serverTime);
	debug logRequest(req, res);
}