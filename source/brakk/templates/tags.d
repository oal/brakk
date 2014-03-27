module brakk.templates.tags;

import std.string : startsWith, strip;
import std.conv : to;
import std.algorithm : findSplitAfter;
import brakk.templates.base : Node, Parser, Token, render, ErrorNode;
import brakk.templates.helpers : illegalParens;

class CommentNode : Node
{
	override string render()
	{
		return "";
	}
}

Node commentTag(Parser parser, Token token)
{
	parser.skipPast("endcomment");
	return new CommentNode();
}

Node ifTag(Parser parser, Token token)
{
	Node node = new Node();

	node.writeCode("if(mixin(q{" ~ token.value[3..$] ~ "})){");
	
	Node[] childNodes = parser.parse(["elif", "else", "endif"]);
	node.writeCode(childNodes.render());
	token = parser.nextToken();
	
	while(token.value.startsWith("elif"))
	{		
		childNodes = parser.parse(["elif", "else", "endif"]);
		node.writeCode("} else if(mixin(q{" ~ token.value[5..$] ~ "})){");
		node.writeCode(childNodes.render());
		token = parser.nextToken();
	}
	
	if(token.value == "else")
	{
		childNodes = parser.parse(["endif"]);
		node.writeCode("} else {");
		node.writeCode(childNodes.render());
		token = parser.nextToken();
	}
	
	if(token.value == "endif") node.writeCode("}");
	
	return node;
}

Node foreachTag(Parser parser, Token token)
{
	Node node = new Node();

	string data = token.value[8..$];
	if(illegalParens(data)) return new ErrorNode("Illegal use of foreach");

	node.writeCode("foreach(" ~ data ~ "){");
	Node[] childNodes = parser.parse(["endforeach"]);

	node.writeCode(childNodes.render());

	token = parser.nextToken();
	if(token.value == "endforeach") node.writeCode("}");

	return node;
}