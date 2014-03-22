module brakk.templates.tags;

import brakk.templates.base : Parser, Token, Node, Context;
import std.stdio;
import std.conv : to;

class CommentNode : Node
{
	override string render(Context ctx)
	{
		return "";
	}
}

class DebugNode : Node
{
	override string render(Context ctx)
	{
		string text;
		foreach(key, val; ctx)
		{
			text ~= to!string(key) ~ ": \t" ~ to!string(val) ~ "\n";
		}
		return text;
	}
}

// Built in template tags (registered on the templateTags AA in base.d):

Node function(Parser, Token)[string] templateTags;

Node comment(Parser parser, Token token)
{
	parser.skipPast("endcomment");
	return new CommentNode();
}

Node debugContext(Parser parser, Token token)
{
	return new DebugNode();
}