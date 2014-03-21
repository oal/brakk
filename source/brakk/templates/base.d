﻿module brakk.templates.base;

import std.stdio;
import std.string;
import std.ascii;
import std.array;
import std.regex;
import std.variant;
import std.conv : to;
import core.vararg;
import brakk.templates.tags;

static string source = `
<body>
	{# I am a comment #}
	<p>{{ var }}</p>
	{% comment %}
		<strong>{{ var2 }}</strong>
	{% endcomment %}
</body>
`;

alias Context = Variant[string];

Context context(T...)(T t)
{
	Context data;
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
	int line;
}

class Lexer
{
	string templateString;
	int line = 0;

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
				
				if(prevToken == TokenType.Text)
				{
					tokens ~= Token(prevToken, templateString[start..i-1], line);
					line += tokens[$-1].value.count("\n");
				}
				start = i+1;
			}
			else if(currToken && curr == '}')
			{
				if((prev == '%' && currToken == TokenType.Block) ||
				   (prev == '#' && currToken == TokenType.Comment) ||
				   (prev == '}' && currToken == TokenType.Var)) {
					tokens ~= Token(currToken, templateString[start..i-1].strip(), line);
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
			tokens ~= Token(TokenType.Text, templateString[start..i-1], line);
		}
		return tokens;
	}
}

class Node
{
	bool mustBeFirst;

	string render(Context ctx)
	{
		return "";
	}
}

class TextNode : Node
{
	string content;

	this(string content)
	{
		this.content = content;
	}

	override string render(Context ctx)
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
	
	override string render(Context ctx)
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

	string render(Context context)
	{
		string result;
		foreach(node; nodes) result ~= node.render(context);

		return result;
	}
}

class Tag {}

Tag[string] tags;

class TemplateSyntaxError : Exception
{
	this (string msg)
	{
		super(msg);
	}
}

class Parser
{
	Token[] tokens;

	this(Token[] tokens)
	{
		this.tokens = tokens;
	}

	NodeList parse(string parseUntil="")
	{
		auto nodes = new NodeList();
		while(tokens.length)
		{
			auto token = nextToken();
			switch(token.type)
			{
				default: break;
				case TokenType.Text:
					nodes.add(new TextNode(token.value));
					break;
				case TokenType.Var:
					nodes.add(new VarNode(token.value));
					break;
				case TokenType.Block:
					string command;
					try command = token.value.split(" ")[0];
					catch (RangeError) emptyBlockTag(token);

					if(parseUntil == "end"~command)
					{
						prependToken(token);
						return nodes;
					}

					Tag blockCommand;
					try blockCommand = tags[command];
					catch (RangeError) invalidBlockTag(token, command, parseUntil);

					//blockCommand(this, token);
					break;
			}
		}
		return nodes;
	}

	Token nextToken()
	{
		auto token = tokens[0];
		tokens.popFront();
		return token;
	}

	void prependToken(Token token)
	{
		tokens.insertInPlace(0, token);
	}

	void error(Token token, string msg)
	{
		throw new TemplateSyntaxError("Line " ~ to!string(token.line) ~": " ~ msg);
	}

	void emptyBlockTag(Token token)
	{
		error(token, "Empty block tag");
	}

	void invalidBlockTag(Token token, string command, string parseUntil)
	{
		auto msg="Invalid block tag: " ~ command;
		if(parseUntil.length) msg ~= ", expected " ~ parseUntil;
		error(token, msg);
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