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
		output.put("buf.put(\""~text.replace(`"`, `\"`)~"\");\n");
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
	string[] ttKeys;
	tagFunc[] ttFuncs;

	// Lexer
	string text;
	int lexerCounter;
	TokenType prevToken = TokenType.text;
	Token[] tokens;

	// Parser
	int tokenCounter;
	bool eof;

	this(string text, string[] ttKeys, tagFunc[] ttFuncs)
	{
		this.text = text;
		this.ttKeys = ttKeys;
		this.ttFuncs = ttFuncs;
	}

	Token nextToken()
	{
		Token token = parseNextToken();
		tokens ~= token;
		tokenCounter++;
		return token;
	}

	// Lexer related
	Token parseNextToken()
	{
		int start = -1;
		Token token;

		while(lexerCounter < text.length-1)
		{
			auto curr = text[lexerCounter];
			auto next = text[lexerCounter+1];

			// Token type
			if(start == -1)
			{
				if(curr == '{')
				{
					switch(next)
					{
						case '{':
							token.type = TokenType.variable;
							start = lexerCounter+2;
							break;
						case '%':
							token.type = TokenType.block;
							start = lexerCounter+2;
							break;
						case '#':
							token.type = TokenType.comment;
							start = lexerCounter+2;
							break;
						default: break;
					}
				}
				if(token.type == TokenType.text) start = lexerCounter;
				lexerCounter++;
				continue;
			}

			// Insert token
			if(token.type != TokenType.text && next == '}')
			{
				switch(curr)
				{
					case '}', '%', '#':
						token.value = text[start..lexerCounter].strip();
						lexerCounter += 2;
						goto Return;
					default: break;
				}
			}
			else if(token.type == TokenType.text && curr == '{')
			{
				switch(next)
				{
					case '{', '%', '#':
						token.value = text[start..lexerCounter];
						goto Return;
					default: break;
				}
			}
			lexerCounter++;
		}
		token.value = text[start..lexerCounter+1];
		eof = true;
	Return:
		return token;
	}

	// Parser related
	Node[] parse(string[] parseUntil=[])
	{
		Node[] nodes;

		while(!eof)
		{
			Token token = nextToken();
			switch(token.type)
			{
				case TokenType.text:
					nodes ~= new TextNode(token.value);
					break;
				case TokenType.variable:
					nodes ~= new VariableNode(token.value);
					break;
				case TokenType.block:
					string command = token.value.split(" ")[0];

					if(parseUntil.countUntil(command) != -1)
					{
						back();
						return nodes;
					}

					auto dg = ttFuncs[ttKeys.countUntil(command)];
					nodes ~= dg(this, token);

					break;
				default: break;
			}
		}
		return nodes;
	}

	void back()
	{
		tokenCounter--;
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
}

alias Node function(Parser, Token) tagFunc;

string parseTemplate(string text)
{
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
	output.put("//" ~ to!string(ttKeys) ~ "\n");

	auto parser = new Parser(text, ttKeys, ttFuncs);
	auto nodes = parser.parse();

	foreach(node; nodes)
	{
		output.put(node.render());
	}

	return output.data;
}