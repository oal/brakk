module brakk.templates.helpers;

bool illegalParens(string code)
{
	bool inDouble;
	bool inSingle;
	bool inBackquotes;
	int numOpening;
	
	foreach(c; code)
	{
		switch(c)
		{
			case '\'': inSingle = !inSingle; break;
			case '"': inDouble = !inDouble; break;
			case '`': inBackquotes = !inBackquotes; break;
			case '(': numOpening++; break;
			default: break;
		}

		if(c == ')' && (!inSingle && !inDouble && !inBackquotes) && numOpening % 2 != 1)
		{
			return true;
		}
	}
	return false;
}

unittest
{
	assert(!illegalParens("()"));
	assert(illegalParens(`b; 1..2){} writeln("..."); foreach(int i; 0..1000`));
}