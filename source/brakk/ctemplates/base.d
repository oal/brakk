// Attempt at compile time templates.
module brakk.ctemplates.base;

import std.stdio;
import std.algorithm;
import std.file;
import std.string;
import std.array;
import std.functional;
import std.conv : to;
import core.vararg;
import vibe.d : HTTPServerRequest, HTTPServerResponse;
import ttags = brakk.ctemplates.tags;

template localAliases(int i, ALIASES...)
{
	static if( i < ALIASES.length )
		enum string localAliases = "alias ALIASES[" ~ to!string(i) ~ "] " ~ __traits(identifier, ALIASES[i]) ~ ";\n" ~ localAliases!(i + 1, ALIASES);
	else
		enum string localAliases = "";
}

void renderTemplate(string templateFile, ALIASES...)(HTTPServerRequest req, HTTPServerResponse res)
{
	static string cttostring(T)(T val)
	{
		static if (is(T == string))
			return val;
		else static if(__traits(compiles, val.opCast!string()))
			return cast(string)val;
		else static if(__traits(compiles, val.toString()))
			return val.toString();
		else
			return to!string(val);
	}

	mixin(localAliases!(0, ALIASES));
	Appender!string buf;

	pragma(msg, "Compiling template file " ~ templateFile);
	enum emissionCode = parseTemplate(import(templateFile)); //, genFileTable!templateFile);
	writeln(emissionCode);
	/*
	static struct tmplRoot
	{
		static void emptyBlock(ref Appender!string buf) { }
		
		mixin(emissionCode);
	}
	tmplRoot.tmplMain(buf);*/

	mixin(emissionCode);
	res.writeBody(buf.data, "text/html; charset=UTF-8");
}


enum TokenType
{
	text,
	variable,
	block,
	comment
}

static struct Token
{
	TokenType type;
	string value;
}

class Lexer
{
	string text;
	this(string text)
	{
		this.text = text;
	}

	Token[] tokenize()
	{
		Token[] tokens;
		void addToken(TokenType type, string value)
		{
			if(value.length == 0) return;
			tokens ~= Token(type, value);
		}

		TokenType currToken = TokenType.text;
		int start;
		int startVerbatim = -1;

		int i = 1;
		char prev = text[0];
		while(i < text.length)
		{
			auto curr = text[i];
			if(currToken == TokenType.text && prev == '{')
			{
				switch(curr)
				{
					case '{':
						currToken = TokenType.variable;
						break;
					case '%':
						currToken = TokenType.block;
						break;
					case '#':
						currToken = TokenType.comment;
						break;
					default: break;
				}
				if(currToken != TokenType.text)
				{
					addToken(TokenType.text, text[start..i-1].replace(`"`, `\"`));
					start = i+1;
				}
			}
			else if(currToken != TokenType.text && curr == '}')
			{
				switch(prev)
				{
					case '}', '#':
						addToken(currToken, text[start..i-1].strip());
						currToken = TokenType.text;
						start = i+1;
						break;
					case '%':
						auto value = text[start..i-1].strip();
						if(value == "verbatim") startVerbatim = i+1;
						else if(value == "endverbatim")
						{
							addToken(currToken, text[startVerbatim..i-16]);
							startVerbatim = -1;
						}
						else
						{
							addToken(currToken, value);
						}
						currToken = TokenType.text;
						start = i+1;
						break;
					default: break;
				}
			}
			prev = curr;
			i++;
		}
		addToken(TokenType.text, text[start..i].replace(`"`, `\"`));
		return tokens;
	}
}

class Node
{
	Appender!string output;

	this(){}

	void writeText(string text)
	{
		output.put("buf.put(\""~text~"\");\n");
	}

	void writeCode(string code)
	{
		output.put(code~"\n");
	}

	string render()
	{
		return output.data;
	}
}

class TextNode : Node
{
	this(string text)
	{
		writeText(text);
	}
}

class VariableNode : Node
{
	this(string varValue)
	{
		writeCode("buf.put(to!string("~varValue~"));");
	}
}

class Parser
{
	Token[] tokens;
	string[] ttKeys;
	tagFunc[] ttFuncs;

	this(Token[] tokens, string[] ttKeys, tagFunc[] ttFuncs)
	{
		this.tokens = tokens;
		this.ttKeys = ttKeys;
		this.ttFuncs = ttFuncs;
	}

	Node[] parse(string[] parseUntil=[])
	{
		Node[] nodes;

		while(tokens.length)
		{
			Token token = nextToken();
			switch(token.type)
			{
				case TokenType.text:
					nodes ~= new TextNode(token.value);
					//output.put("buf ~= \""~token.value~"\";\n");
					break;
				case TokenType.variable:
					nodes ~= new VariableNode(token.value);
					//output.put("buf ~= to!string("~token.value~");\n");
					break;
				case TokenType.block:
					string command = token.value.split(" ")[0];

					if(parseUntil.countUntil(command) != -1)
					{
						prependToken(token);
						return nodes;
					}

					auto dg = ttFuncs[ttKeys.countUntil(command)];
					nodes ~= dg(this, token);

					//if(command in templateTags) templateTags[command](this, token);

					break;
				default:
					//output ~= `buf ~= "[[`~token.value~"]]\";\n";
					break;
			}
		}
		return nodes;
	}

	void skipPast(string endTag)
	{
		while(tokens.length)
		{
			Token token = nextToken();
			if(token.type == TokenType.block && token.value == endTag) return;
		}
		// Error
	}

	Token nextToken()
	{
		Token token = tokens[0];
		tokens.popFront();
		return token;
	}

	void prependToken(Token token)
	{
		tokens.insertInPlace(0, token);
	}
}

alias Node function(Parser, Token) tagFunc;

string parseTemplate(string text)
{
	auto lexer = new Lexer(text);
	auto tokens = lexer.tokenize();

	Appender!string output;

	// Use two arrays instead of an associative array to get around CTFE limitation.
	string[] ttKeys;
	tagFunc[] ttFuncs;
	string genTagsMap()
	{
		string b;
		foreach(mem; __traits(derivedMembers, ttags))
		{
			if(mem[$-3..$] == "Tag")
			{
				//output.put("// templateTags[\""~mem~"\"] = &ttags."~mem~";\n");
				b ~= "ttKeys ~= \""~mem[0..$-3]~"\";\n";
				b ~= "ttFuncs ~= &ttags."~mem~";\n";
			}
		}
		return b;
	}
	mixin(genTagsMap());

	// Tmp:
	output.put("//"~to!string(ttKeys)~"\n");

	auto parser = new Parser(tokens, ttKeys, ttFuncs);
	auto nodes = parser.parse();

	foreach(node; nodes)
	{
		output.put(node.render());
	}
	return output.data;
}