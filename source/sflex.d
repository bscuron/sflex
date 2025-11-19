module sflex;

import std.stdio;
import std.array;
import std.parallelism;
import std.algorithm;
import std.range;
import std.file;
import std.mmfile;
import std.typecons;
import std.math;
import std.functional;
import std.uni;
import std.string;
import std.conv;
import std.meta;
import std.utf;

enum TokenType
{
	Unknown,

	// Keyword
	Keyword,

	// Identifier
	Identifier,

	// Comments
	CommentLine,
	CommentBlock,

	// Literals
	LiteralString,
	LiteralFloat,
	LiteralInteger,

	// Punctuation
	PunctuationLeftParenthesis = '(',
	PunctuationRightParenthesis = ')',
	PunctuationLeftBrace = '{',
	PunctuationRightBrace = '}',
	PunctuationLeftBracket = '[',
	PunctuationRightBracket = ']',
	PunctuationSemicolon = ';',
	PunctuationComma = ',',
	PunctuationDot = '.',
	PunctuationQuestion = '?',
	PunctuationColon = ':',
	PunctuationPlus = '+',
	PunctuationMinus = '-',
	PunctuationStar = '*',
	PunctuationSlash = '/',
	PunctuationPercent = '%',
	PunctuationAmpersand = '&',
	PunctuationPipe = '|',
	PunctuationCaret = '^',
	PunctuationTilde = '~',
	PunctuationLess = '<',
	PunctuationGreater = '>',
	PunctuationEquals = '=',
	PunctuationBang = '!',
	PunctuationAt = '@',
}

const bool[string] Keywords = [
	"abstract",
	"activate",
	"and",
	"any",
	"array",
	"as",
	"asc",
	"autonomous",
	"begin",
	"bigdecimal",
	"blob",
	"boolean",
	"break",
	"bulk",
	"by",
	"byte",
	"case",
	"cast",
	"catch",
	"char",
	"class",
	"collect",
	"commit",
	"const",
	"continue",
	"currency",
	"date",
	"datetime",
	"decimal",
	"default",
	"delete",
	"desc",
	"do",
	"double",
	"else",
	"end",
	"enum",
	"exception",
	"exit",
	"export",
	"extends",
	"false",
	"final",
	"finally",
	"float",
	"for",
	"from",
	"global",
	"goto",
	"group",
	"having",
	"hint",
	"if",
	"implements",
	"import",
	"in",
	"inner",
	"insert",
	"instanceof",
	"int",
	"integer",
	"interface",
	"into",
	"join",
	"like",
	"limit",
	"list",
	"long",
	"loop",
	"map",
	"merge",
	"new",
	"not",
	"null",
	"nulls",
	"number",
	"object",
	"of",
	"on",
	"or",
	"outer",
	"override",
	"package",
	"parallel",
	"pragma",
	"private",
	"protected",
	"public",
	"retrieve",
	"return",
	"rollback",
	"select",
	"set",
	"short",
	"sobject",
	"sort",
	"static",
	"string",
	"super",
	"switch",
	"synchronized",
	"system",
	"testmethod",
	"then",
	"this",
	"throw",
	"time",
	"transaction",
	"trigger",
	"true",
	"try",
	"undelete",
	"update",
	"upsert",
	"using",
	"virtual",
	"void",
	"webservice",
	"when",
	"where",
	"while",
].map!(keyword => Tuple!(string, bool)(keyword, true)).array.assocArray;

final struct Token
{
	TokenType type;
	string value;
	ulong line;
	ulong column;
}

final class Lexer
{
	typeof(byUTF!char("")) data;
	ulong line;                               // line offset
	@property ulong column() => offset - bol; // column offset
	ulong bol;                                // beginning of line offset
	ulong offset;                             // byte offset

	this(string data)
	{
		this.data = data.byUTF!char;
	}

	char front() => data[offset];

	void popFront()
	{
		if (!empty && front == '\n')
		{
			line++;
			bol = offset + 1;
		}
		offset++;
	}

	bool empty() => data.empty || offset > data.length - 1;

	ulong length() => data.length;

	char moveFront() => front;

	int opApply(scope int delegate(char) dg)
	{
		while (!empty)
		{
			auto ret = dg(front);
			if (ret)
			{
				return ret;
			}
			popFront;
		}
		return 0;
	}

	int opApply(scope int delegate(ulong, char) dg)
	{
		while (!empty)
		{
			auto ret = dg(offset, front);
			if (ret)
			{
				return ret;
			}
			popFront;
		}
		return 0;
	}

	// NOTE: since index op is used for offset relative to the lexer's byte
	// offset, it is probably ok that i is signed. This allows negative
	// offsets.
	char opIndex(long i) => data[offset + i];
}

void chopWhile(alias pred)(Lexer lexer, RefAppender!string appender)
{
	while (!lexer.empty && pred(lexer.front)) 
	{
		appender ~= lexer.front;
		lexer.popFront;
	}
}

void chopUntil(alias pred)(Lexer lexer, RefAppender!string appender)
{
	lexer.chopWhile!(not!pred)(appender);
}

void chopLine(Lexer lexer, RefAppender!string appender)
{
	lexer.chopUntil!"a=='\\n'"(appender);
}

Token chopTokenCommentLine(Lexer lexer)
{
	auto token = Token();
	token.line = lexer.line;
	token.column = lexer.column;
	auto appender = appender(&token.value);
	lexer.chopLine(appender);
	token.type = TokenType.CommentLine;
	return token;
}

Token chopTokenCommentBlock(Lexer lexer)
{
	auto token = Token();
	token.line = lexer.line;
	token.column = lexer.column;
	auto appender = appender(&token.value);

	for (;;)
	{
		lexer.chopUntil!"a=='*'"(appender);
		if (lexer.empty)
		{
			break;
		}
		else if (lexer[1] == '/')
		{
			token.type = TokenType.CommentBlock;
			appender ~= lexer.takeExactly(2LU);
			break;
		}
		else
		{
			appender ~= lexer.front;
			lexer.popFront;
		}
	}
	token.value = appender[];

	return token;
}

Token chopTokenLiteralString(Lexer lexer)
{
	auto token = Token();
	token.line = lexer.line;
	token.column = lexer.column;
	auto appender = appender(&token.value);
	appender ~= lexer.takeExactly(1LU);

	for (;;)
	{
		lexer.chopUntil!"a=='\\\''"(appender);
		if (lexer.empty)
		{
			token.value = appender[];
			break;
		}
		else if (lexer[-1] != '\\')
		{
			token.type = TokenType.LiteralString;
			token.value = appender[][1..$];
			lexer.popFrontExactly(1LU);
			break;
		}
		else
		{
			appender ~= lexer.front;
			lexer.popFront;
		}
	}

	return token;
}

Token chopTokenLiteralNumber(Lexer lexer)
{
	auto token = Token();
	token.line = lexer.line;
	token.column = lexer.column;
	auto appender = appender(&token.value);
	lexer.chopWhile!isNumber(appender);
	token.type = TokenType.LiteralInteger;

	if (!lexer.empty && lexer[0] == '.' && lexer.offset + 1 < lexer.length - 1 && lexer[1].isNumber)
	{
		appender ~= lexer.takeExactly(1LU);
		lexer.chopWhile!isNumber(appender);
		token.type = TokenType.LiteralFloat;
	}

	return token;
}

// TODO: allow only valid apex punctuation
Token chopTokenPunctuation(Lexer lexer)
{
	auto token = Token();
	token.line = lexer.line;
	token.column = lexer.column;
	token.type = cast(TokenType)lexer.front;
	lexer.popFront;
	return token;
}

Token chopTokenIdentifier(Lexer lexer)
{
	auto token = Token();
	token.line = lexer.line;
	token.column = lexer.column;
	auto appender = appender(&token.value);
	appender ~= lexer.front;
	lexer.popFront;

	if (lexer[-1] != '$' || (lexer.offset < lexer.length - 1 && lexer[0].isAlpha))
	{
		lexer.chopWhile!(c => c.isAlphaNum || c == '_')(appender);
		if (token.value.toLower in Keywords)
		{
			token.type = TokenType.Keyword;
		}
		else
		{
			token.type = TokenType.Identifier;
		}
	}
	token.value = appender[];

	return token;
}

Token[] tokenize(T)(string s)
	if (is(T == MmFile) || is(T == File) || is(T == string))
{
	string data;
	static if (is(T == MmFile))
	{
		auto file = scoped!T(s);
		data = cast(string)file[];
	}
	else if (is(T == File))
	{
		data = s.readText;
	}
	else if (is(T == string))
	{
		data = s;
	}
	auto lexer = scoped!Lexer(data);
	auto tokens = Appender!(Token[]).init;

	while (!lexer.empty)
	{
		// single-line comment
		if (lexer[0] == '/' && lexer[1] == '/')
		{
			tokens ~= lexer.chopTokenCommentLine;
		}

		// multi-line comment
		else if (lexer[0] == '/' && lexer[1] == '*')
		{
			tokens ~= lexer.chopTokenCommentBlock;
		}

		// literal string
		else if (lexer[0] == '\'')
		{
			tokens ~= lexer.chopTokenLiteralString;
		}

		// literal number
		else if (lexer[0].isNumber)
		{
			tokens ~= lexer.chopTokenLiteralNumber;
		}

		// identifier/keyword
		else if (lexer[0].isAlpha || lexer[0] == '$')
		{
			tokens ~= lexer.chopTokenIdentifier;
		}

		// punctuation
		else if (lexer[0].isPunctuation)
		{
			tokens ~= lexer.chopTokenPunctuation;
		}

		// whitespace
		else
		{
			lexer.popFront;
		}
	}

	return tokens[];
}
