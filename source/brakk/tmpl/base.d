module brakk.tmpl.base;

import std.algorithm : countUntil;
import std.stdio : writeln;
import std.array : Appender;
import std.conv : to;
import std.string : strip, split;
import brakk.http : HTTPServerRequest, HTTPServerResponse;
import ttags = brakk.tmpl.tags;

template localAliases(int i, ALIASES...)
{
	static if( i < ALIASES.length )
		enum string localAliases = "alias ALIASES[" ~ to!string(i) ~ "] " ~ __traits(identifier, ALIASES[i]) ~ ";\n" ~ localAliases!(i + 1, ALIASES);
	else
		enum string localAliases = "";
}

void renderTemplate(string templateFile, ALIASES...)(HTTPServerRequest req, HTTPServerResponse res)
{
	mixin(localAliases!(0, ALIASES));
	Appender!string buf;
	
	pragma(msg, "Compiling template file " ~ templateFile);
	enum emissionCode = parseTemplate(import(templateFile), genFileTable!templateFile);
	writeln(emissionCode);

	//mixin(emissionCode);
	
	res.writeBody(buf.data, "text/html; charset=UTF-8");
}

alias Node function(Template, Parser, Token) templateTag;

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

class Node
{
	string data;

	this(string data="")
	{
		this.data = data;
	}

	string render()
	{
		return data;
	}
}

class BlockNode : Node {
	Node[] nodes;

	this(string data="")
	{
		super(data);
	}

	override string render()
	{
		data = "";
		foreach(node; nodes) data ~= node.render();

		return data;
	}

	override string toString()
	{
		return "Block: " ~ render();
	}
}


class Parser
{
	Template tmpl;
	string text;
	bool isExtended;
	Token[] tokens;
	int tokenCounter;
	int scanPos;
	bool eof;

	this(Template tmpl, string text)
	{
		this.tmpl = tmpl;
		this.text = text;
	}

	Token nextToken()
	{
		tokenCounter++;
		if(tokens.length > tokenCounter-1)
		{
			return tokens[tokenCounter-1];
		}
		return scanNextToken();
	}

	Token scanNextToken()
	{
		if(scanPos == text.length) return Token();

		int start = scanPos;
		TokenType currToken;
		string value;
		char closing;

		if(text[scanPos] == '{')
		{
			switch(text[scanPos+1])
			{
				case '{':
					currToken = TokenType.variable;
					closing = '}';
					break;
				case '%': 
					currToken = TokenType.block;
					closing = '%';
					break;
				case '#':
					currToken = TokenType.comment;
					closing = '#';
					break;
				default:
					break;
			}
		}

		if(currToken == TokenType.text)
		{
			char p, c;

			while(!(p == '{' && (c == '{' || c == '%' || c == '#')) && scanPos < text.length-1)
			{
				p = text[scanPos];
				scanPos++;
				c = text[scanPos];
			}

			scanPos--;
			if(scanPos == text.length-2)
			{
				value = text[start..text.length];
				scanPos = to!int(text.length);
			}
			else value = text[start..scanPos];
		}
		else
		{
			char p, c;

			while(!(c == '}' && p == closing) && scanPos < text.length-1)
			{
				p = text[scanPos];
				scanPos++;
				c = text[scanPos];
			}

			scanPos++;
			value = text[start+2..scanPos-2].strip();
		}

		if(scanPos == text.length) eof = true;
		//assert(value.length);

		auto token = Token(currToken, value);
		tokens ~= token;
		return token;
	}

	void previousToken()
	{
		tokenCounter--;
	}

	void reset()
	{
		tokenCounter = 0;
	}

	Node[] parse(string[] parseUntil=[])
	{
		Node[] nodes;
		Token token = nextToken();
		while(token.value)
		{
			switch(token.type)
			{
				case TokenType.text:
					nodes ~= new Node("buf.put(`"~token.value~"`);\n");
					break;
				case TokenType.variable:
					nodes ~= new Node("buf.put("~token.value~");\n");
					break;
				case TokenType.block:

					string command = token.value.split(" ")[0].strip();
					if(parseUntil.countUntil(command) != -1)
					{
						previousToken();
						return nodes;
					}
					auto index = tmpl.templateTagKeys.countUntil(command);
					if(index != -1)
					{
						auto dg = tmpl.templateTags[tmpl.templateTagKeys.countUntil(command)];
						nodes ~= dg(tmpl, this, token);
					}
					else
					{
						nodes ~= new Node("// UNKNOWN BLOCK: "~token.value~"\n");
					}
					break;
				default: break;
			}
			token = nextToken();
		}
		return nodes;
	}
}

class Template
{
	string text;
	string[string] dependencies;

	Parser parser;
	string[] templateTagKeys;
	templateTag[] templateTags;

	Node[] nodes;
	BlockNode[string] blocks;

	this(string text, string[string] dependencies, string[] templateTagKeys, templateTag[] templateTags)
	{
		this. text = text;
		this.dependencies = dependencies;

		this.templateTagKeys = templateTagKeys;
		this.templateTags = templateTags;

		parser = new Parser(this, text);
		parser.parse();
	}

	string render()
	{
		string data;
		foreach(node; nodes) data ~= node.render();

		return data;
	}
}

string parseTemplate(string text, string[string] fileTable)
{
	mixin(genTemplatetags());
	auto tmpl = new Template(text, fileTable, templateTagKeys, templateTags);

	return tmpl.render();
}


string genTemplatetags()
{
	Appender!string result;
	
	// Use two arrays instead of an associative array to get around CTFE limitation.
	result.put(`
	string[] templateTagKeys;
	templateTag[] templateTags;
	`);
	
	foreach(mem; __traits(derivedMembers, ttags))
	{
		if(mem[$-3..$] == "Tag")
		{
			result.put("templateTagKeys ~= \""~mem[0..$-3]~"\";\n");
			result.put("templateTags ~= &ttags."~mem~";\n");
		}
	}
	return result.data;
}


@property string[string] genFileTable(string baseFileName)()
{
	enum baseFileContents = import(baseFileName);
	static @property void staticEach(alias vals, alias action, params...)()
	{
		static if (vals.length == 0) { } // Do nothing
		else static if (vals.length == 1)
		{
			action!(vals[0], params)();
		}
		else
		{
			action!(vals[0], params)();
			staticEach!(vals[1..$], action, params);
		}
	}
	
	// This works, but it isn't great
	static string[] extractDependencies(string fileContents)
	{
		string[] deps;
		
		int i;
		int start;
		while(i < fileContents.length-1)
		{
			if(!start && fileContents[i] == '{' && fileContents[i + 1] == '%')
				start = i + 2;
			else if(start && fileContents[i] == '%' && fileContents[i + 1] == '}')
			{
				auto block = fileContents[start..i - 1].strip().split(" ");
				switch(block[0])
				{
					case "extends", "include":
						deps ~= block[1].strip();
						break;
					default:
						break;
				}
				start = 0;
			}
			i++;
		}
		
		return deps;
	}
	
	enum directDependencies = extractDependencies(baseFileContents);
	string[string] ret;
	static void addDependencies(string dep, alias ret)()
	{
		ret[dep] = import(dep);
		foreach (k, v; genFileTable!(dep))
			ret[k] = v;
	}
	staticEach!(directDependencies, addDependencies, ret);
	return ret;
}