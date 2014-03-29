module brakk.templates.tags;

import std.string : startsWith, strip, split;
import std.conv : to;
import std.algorithm : findSplitAfter;
import brakk.templates.base : Node, Template, Token, render, ErrorNode, parseTemplate, BlockNode;
import brakk.templates.helpers : illegalParens;

class CommentNode : Node
{
	override string render()
	{
		return "";
	}
}

Node commentTag(Template tmpl, Token token)
{
	tmpl.skipPast("endcomment");
	return new CommentNode();
}

Node ifTag(Template tmpl, Token token)
{
	Node node = new Node();

	node.writeCode("if(mixin(q{" ~ token.value[3..$] ~ "})){");
	
	Node[] childNodes = tmpl.parse(["elif", "else", "endif"]);
	node.writeCode(childNodes.render());
	token = tmpl.nextToken();

	while(token.value.startsWith("elif"))
	{		
		childNodes = tmpl.parse(["elif", "else", "endif"]);
		node.writeCode("} else if(mixin(q{" ~ token.value[5..$] ~ "})){");
		node.writeCode(childNodes.render());
		token = tmpl.nextToken();
	}
	
	if(token.value == "else")
	{
		childNodes = tmpl.parse(["endif"]);
		node.writeCode("} else {");
		node.writeCode(childNodes.render());
		token = tmpl.nextToken();
	}
	
	if(token.value == "endif") node.writeCode("}");
	
	return node;
}

Node foreachTag(Template tmpl, Token token)
{
	Node node = new Node();

	string data = token.value[8..$];
	if(illegalParens(data)) return new ErrorNode("Illegal use of foreach");

	node.writeCode("foreach(" ~ data ~ "){");
	Node[] childNodes = tmpl.parse(["endforeach"]);

	node.writeCode(childNodes.render());

	token = tmpl.nextToken();
	if(token.value == "endforeach") node.writeCode("}");

	return node;
}

/*Node includeTag(Template tmpl, Token token)
{
	Node node = new Node();
	
	string data = token.value.split(" ")[1][1..$ - 1];
	node.writeCode("// Begin include");
	node.writeCode(parseTemplate(tmpl.dependencies[data], tmpl.dependencies));
	node.writeCode("// End include");
	return node;
}*/

Node blockTag(Template tmpl, Token token)
{
	auto node = new BlockNode();
	auto blockName = token.value.split(" ")[1];
	
	if(tmpl.isRoot) 
	{
		BlockNode block = tmpl.root.blocks[blockName];
		node.writeCode(block.render());
	}
	else
	{
		tmpl.parse(["endblock"]);
		//node.writeCode(nodes.render());
		tmpl.root.blocks[blockName] = node;
	}
	return node;
}

Node extendsTag(Template tmpl, Token token)
{
	Node node = new Node();

	if(tmpl.tokens.length != 1) return node;
	
	string filename = token.value.split(" ")[1][1..$ - 1];
	auto subTemplate = tmpl.subTemplate(filename);
	subTemplate.parse();
	/*
	while(true)
	{
		auto nodes = subTemplate.parse(["block"]);
		node.writeCode(nodes.render());
		auto tv = subTemplate.nextToken().value;
		if(!tv) break;
		auto block = tv.split(" ")[1].strip();
		auto blockNode = new BlockNode();

		nodes = subTemplate.parse(["endblock"]);
		blockNode.writeCode(nodes.render());
		tmpl.blocks[block] = blockNode;
	}*/
	return node;
}

