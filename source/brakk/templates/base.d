module brakk.templates.base;

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
	<p>{{ var|myfilter:"arg":var:"arg3" }}</p>
	{% comment %}
		<strong>{{ var2 }}</strong>
	{% endcomment %}

	{{ kv.key }}

	{% verbatim %}
		{{ var }}
		{% comment %}Comment{% endcomment %}
	{% endverbatim %}

	<p>{{var2}}</p>
	<pre>{% debug %}</pre>
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
		int startVerbatim = -1;
		
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
					auto value = templateString[start..i-1].strip();

					// Everything between {% verbatim %} and {% endverbatim %} should be a Text token.
					if(currToken == TokenType.Block && value == "verbatim")
					{
						startVerbatim = i+1;
						start = startVerbatim;
						currToken = TokenType.Text;
						continue;
					}
					else if(currToken == TokenType.Block && value == "endverbatim")
					{
						currToken = TokenType.Text;
						tokens ~= Token(currToken, templateString[startVerbatim..start-2], line);
						startVerbatim = -1;
						start = i+1;
						continue;
					}

					// Any other token.
					tokens ~= Token(currToken, value, line);
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
	string tokenValue;
	string[] keys;
	FilterToken[] filters;
	
	this(string tokenValue)
	{
		this.tokenValue = tokenValue;
		int firstFilterAt = to!int(tokenValue.indexOf('|'));

		if(firstFilterAt == -1)
		{
			keys = tokenValue.split(".");
		}
		else
		{
			keys = tokenValue[0..firstFilterAt].split(".");
			parseFilters(firstFilterAt);
		}
	}
	
	void parseFilters(int i)
	{
		int start;
		bool inFilter;
		bool inArgument;
		
		FilterToken filter;
		
		auto len = tokenValue.length;
		while(i < len)
		{
			auto c = tokenValue[i];
			if(!inArgument && c == '|')
			{
				start = i+1;
				inFilter = true;
				filter = FilterToken();
			}
			else if(inFilter && (c == ':' || i == len - 1))
			{
				filter.name = tokenValue[start..i];
				inFilter = false;
				inArgument = true;
				start = i+1;
			}
			else if(inArgument && (c == ':' || i == len - 1))
			{
				if(i == len - 1) i++;
				auto argType = FilterArgTokenType.Var;
				auto argValue = tokenValue[start..i];
				if(argValue.front == '"' && argValue.back == '"')
				{
					argType = FilterArgTokenType.Text;
					argValue = argValue[1..$-1];
				}
				
				filter.arguments ~= FilterArgToken(argType, argValue);
				start = i+1;
			}
			i++;
		}
		
		filters ~= filter;
	}

	override string render(Context ctx)
	{
		writeln(keys);
		auto val = ctx[keys[0]];
		if(keys.length > 1)
		{
			foreach(key; keys[1..$]) val = val[key];
		}
		return val.toString();
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

class TemplateSyntaxError : Exception
{
	this (string msg)
	{
		super(msg);
	}
}

// Filters

enum FilterArgTokenType
{
	Text,
	Var
}

struct FilterArgToken
{
	FilterArgTokenType type;
	string value;
}

struct FilterToken
{
	string name;
	FilterArgToken[] arguments;

	string[] resolve(Context ctx)
	{
		string[] args;
		foreach(arg; arguments)
		{
			switch(arg.type)
			{
				default: continue;
				case FilterArgTokenType.Text:
					args ~= arg.value;
					break;
				case FilterArgTokenType.Var:
					args ~= to!string(ctx[arg.value]);
					break;
			}
		}

		return args;
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

					try 
					{
						auto blockCommand = templateTags[command];
						Node node = blockCommand(this, token);
						nodes.add(node);
					}
					catch (RangeError) invalidBlockTag(token, command, parseUntil);
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

	void skipPast(string endTag)
	{
		while(tokens.length)
		{
			auto token = nextToken();
			if(token.type == TokenType.Block && token.value == endTag) return;
		}
		unclosedBlockTag(endTag);
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

	void unclosedBlockTag(string tag)
	{
		throw new TemplateSyntaxError("Unclosed block tag: " ~ tag);
	}
}


shared static this()
{
	templateTags["comment"] = &comment;
	templateTags["debug"] = &debugContext;

	auto lexer = new Lexer(source);
	auto tokens = lexer.tokenize();

	auto parser = new Parser(tokens);
	auto nodes = parser.parse();

	string[string] kv;
	kv["key"] = "value";

	writeln(nodes.render(context(
		"var", "Hei",
		"var2", "MMM",
		"kv", kv
	)));
}