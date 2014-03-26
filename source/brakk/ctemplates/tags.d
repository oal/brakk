module brakk.ctemplates.tags;

import brakk.ctemplates.base : Node, Parser, Token;

class CommentNode : Node
{
	override string render()
	{
		return "// Comment\n";
	}
}

Node commentTag(Parser parser, Token token)
{
	parser.skipPast("endcomment");
	return new CommentNode();
}