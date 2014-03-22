module brakk.templates.filters;

import std.string : toUpper;
import std.conv : to;

string function(string, string[])[string] defaultFilters;

string capfirst(string value, string[] args)
{
	return to!string(value[0].toUpper()) ~ value[1..$];
}