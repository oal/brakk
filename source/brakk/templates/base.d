// Attempt at compile time templates.
module brakk.templates.base;

import std.stdio;
import std.algorithm;
import std.file;
import std.string;
import std.array;
import std.functional;
import std.conv : to;
import core.vararg;
import vibe.d : HTTPServerRequest, HTTPServerResponse;
import brakk.templates.helpers : illegalParens;
import ttags = brakk.templates.tags;

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

	enum aaa = genFileTable!templateFile;
	writeln(aaa);
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

class Node
{
	Appender!string output;
	
	this(){}
	
	void writeText(string text)
	{
		output.put("buf.put(\""~text.replace(`\`, `\\`).replace(`"`, `\"`)~"\");\n");
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

class ErrorNode : Node
{
	this(string text)
	{
		writeCode("writeln(`ERROR: " ~ text ~ "`);");
	}
}

string render(Node[] nodes)
{
	Appender!string output;
	foreach(node; nodes) output.put(node.render());
	return output.data;
}

class Parser
{
	string[string] dependencies;
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
	
	this(string text, string[string] dependencies, string[] ttKeys, tagFunc[] ttFuncs)
	{
		this.text = text;
		this.dependencies = dependencies;
		this.ttKeys = ttKeys;
		this.ttFuncs = ttFuncs;
	}
	
	Token nextToken()
	{
		if(tokens.length > tokenCounter)
		{
			tokenCounter++;
			return tokens[tokenCounter-1];
		}
		
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
					if(next == '{') token.type = TokenType.variable;
					else if(next == '%') token.type = TokenType.block;
					else if(next == '#') token.type = TokenType.comment;
				}
				if(token.type == TokenType.text) start = lexerCounter;
				else start = lexerCounter + 2;
				
				lexerCounter++;
				continue;
			}
			
			// Insert token
			if((token.type != TokenType.text && next == '}')
			   && ((curr == '}' && token.type == TokenType.variable)
			    || (curr == '%' && token.type == TokenType.block)
			    || (curr == '#' && token.type == TokenType.comment)))
			{
				token.value = text[start..lexerCounter].strip();
				lexerCounter += 2;
				goto Return;
			}
			else if(token.type == TokenType.text && curr == '{' &&
			        (next == '{' || next == '%' || next == '#'))
			{
				token.value = text[start..lexerCounter];
				goto Return;
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
					string command = token.value.split(" ")[0].strip();
					
					if(parseUntil.countUntil(command) != -1)
					{
						back();
						return nodes;
					}
					
					auto index = ttKeys.countUntil(command);
					if(index != -1)
					{
						auto dg = ttFuncs[ttKeys.countUntil(command)];
						nodes ~= dg(this, token);
					}
					
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

string parseTemplate(string text, string[string] fileTable)
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
				b ~= "ttKeys ~= \""~mem[0..$-3]~"\";\n";
				b ~= "ttFuncs ~= &ttags."~mem~";\n";
			}
		}
		return b;
	}
	mixin(genTagsMap());
	
	// Tmp:
	output.put("//" ~ to!string(ttKeys) ~ "\n");
	
	auto parser = new Parser(text, fileTable, ttKeys, ttFuncs);
	auto nodes = parser.parse();
	
	output.put(nodes.render());
	
	return output.data;
}

private:

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
						deps ~= block[1].strip()[1..$-1];
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