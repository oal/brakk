module brakk.templates;

import std.stdio;
import std.string;
import std.ascii;
import std.regex;
import std.variant;
import core.vararg;

static string source = `
<body>
	{# I am a comment #}
	<p>{{ var }}</p>
	<strong>{{ var2 }}</strong>
</body>
`;

Variant[string] context(T...)(T t)
{
	Variant[string] data;
	string lastString;
	foreach(idx, arg; t)
	{
		static if(idx % 2 == 0)
		{
			lastString = arg;
		}
		else
		{
			assert(lastString !is null);
			data[lastString] = arg;
			lastString = null;
		}
	}
	return data;
}

enum TokenType
{
	Text,
	Var,
	Block,
	Comment
}

struct Token
{
	TokenType type;
	string value;
}

class Lexer
{
	string templateString;

	this(string templateString)
	{
		this.templateString = templateString;
	}

	Token[] tokenize()
	{
		Token[] tokens;
		
		TokenType currToken;
		int start;
		
		auto i = 1;
		char prev = templateString[0];
		while(i < templateString.length)
		{
			auto curr = templateString[i];
			if(!currToken && prev == '{')
			{
				auto prevToken = currToken;
				if(curr == '%') currToken = TokenType.Block;
				else if(curr == '#') currToken = TokenType.Comment;
				else if(curr == '{') currToken = TokenType.Var;
				else continue;
				
				if(prevToken == TokenType.Text) tokens ~= Token(prevToken, templateString[start..i-1]);
				start = i+1;
			}
			else if(currToken && curr == '}')
			{
				if((prev == '%' && currToken == TokenType.Block) ||
				   (prev == '#' && currToken == TokenType.Comment) ||
				   (prev == '}' && currToken == TokenType.Var)) {
					tokens ~= Token(currToken, templateString[start..i-1].strip());
					currToken = TokenType.Text;
					start = i+1;
				}
			}
			
			prev = curr;
			i++;
		}
		
		// Add the rest of the templateString as text:
		if(start != i)
		{
			tokens ~= Token(TokenType.Text, templateString[start..i-1]);
		}
		return tokens;
	}
}

interface Node
{
	string render(Variant[string]);
}

class TextNode : Node
{
	string content;

	this(string content)
	{
		this.content = content;
	}

	string render(Variant[string] ctx)
	{
		return content;
	}
}

class VarNode : Node
{
	string varName;
	
	this(string varName)
	{
		this.varName = varName;
	}
	
	string render(Variant[string] ctx)
	{
		return ctx[varName].toString();
	}
}

class NodeList
{
	private Node[] nodes;

	void add(Node node)
	{
		nodes ~= node;
	}

	string render(Variant[string] context)
	{
		string result;
		foreach(node; nodes) result ~= node.render(context);

		return result;
	}
}

class Parser
{
	Token[] tokens;

	this(Token[] tokens)
	{
		this.tokens = tokens;
	}

	NodeList parse()
	{
		auto nodes = new NodeList();
		foreach(token; tokens)
		{
			switch(token.type)
			{
				default: break;
				case TokenType.Text:
					nodes.add(new TextNode(token.value));
					break;
				case TokenType.Var:
					nodes.add(new VarNode(token.value));
			}
		}
		return nodes;
	}
}

shared static this()
{
	auto lexer = new Lexer(source);
	auto tokens = lexer.tokenize();
	writeln(tokens);

	auto parser = new Parser(tokens);
	auto nodes = parser.parse();

	writeln(nodes.render(context("var", "Hei", "var2", "MMM")));
}