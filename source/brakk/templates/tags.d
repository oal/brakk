module brakk.templates.tags;

import std.string : startsWith, strip;
import std.conv : to;
import std.algorithm : findSplitAfter;
import brakk.templates.base : Node, Parser, Token, render;

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
	
	string condition = token.value.findSplitAfter(" ")[1];
	node.writeCode("if(" ~ condition ~ "){");
	
	Node[] childNodes = parser.parse(["elif", "else", "endif"]);
	node.writeCode(childNodes.render());
	token = parser.nextToken();
	
	while(token.value.startsWith("elif"))
	{
		condition = token.value.findSplitAfter(" ")[1];
		
		childNodes = parser.parse(["elif", "else", "endif"]);
		node.writeCode("} else if(" ~ condition ~ "){");
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

	string data = token.value.findSplitAfter(" ")[1];

	node.writeCode("foreach(" ~ data ~ "){");
	Node[] childNodes = parser.parse(["endforeach"]);

	node.writeCode(childNodes.render());

	token = parser.nextToken();
	if(token.value == "endforeach") node.writeCode("}");

	return node;
}