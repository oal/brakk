module brakk.templates.tags;

import brakk.templates.base : Parser, Token, Node, Context;
import std.variant;

class CommentNode : Node
{
	override string render(Context ctx)
	{
		return "";
	}
}

Node function(Parser, Token)[string] templateTags;

Node comment(Parser parser, Token token)
{
	parser.skipPast("endcomment");
	return new CommentNode();
};

/*	defaulttags["comment"] = function(Parser parser, Token token)
	{
		parser.skipPast("endcomment");
		return new CommentNode();
	};
*/