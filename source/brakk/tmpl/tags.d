module brakk.tmpl.tags;

import std.stdio : writeln;
import std.string : split, strip;
import brakk.tmpl.base : Template, Token, Parser, Node, BlockNode, TokenType;

Node extendsTag(Template tmpl, Parser parser, Token token)
{
	auto node = new Node();

	auto filename = token.value.split(" ")[1].strip();
	auto subParser = new Parser(tmpl, tmpl.dependencies[filename]);
	auto firstToken = subParser.nextToken();

	if(firstToken.type == TokenType.text)
	{
		subParser.reset();
		auto nodes = subParser.parse();
		tmpl.nodes ~= nodes;
	}
	else
	{
		subParser.reset();
		subParser.parse();
	}

	return node;
}

Node blockTag(Template tmpl, Parser parser, Token token)
{
	auto name = token.value.split(" ")[1].strip();

	BlockNode node;
	if(name in tmpl.blocks) node = tmpl.blocks[name];
	else
	{
		node = new BlockNode();
		tmpl.blocks[name] = node;
	}

	auto nodes = parser.parse(["endblock"]); // Exclude {% endblock %}
	node.nodes = nodes;

	return node;
}