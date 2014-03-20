module brakk.application;

import std.stdio;
import std.string;
import std.range;
import brakk.view;

class Application
{
	private const string name;
	private const string prefix;
	private View[] views;
	
	this(string prefix, string mod=__MODULE__)
	{
		this.name = mod.split(".")[$-2];
		this.prefix = prefix;
	}
	
	void url(string path, View view)
	{
		auto appName = view.classinfo.name.split(".")[0];
		if(appName != name) throw new Exception("Can't register view in another app!");

		auto viewURL = prefix ~ path;
		viewURL = viewURL.replace("//", "/");
		view.setURL(viewURL);

		views ~= view;
	}

	string getName()
	{
		return name;
	}

	string getPrefix()
	{
		return prefix;
	}

	View[] getViews()
	{
		return views;
	}
}