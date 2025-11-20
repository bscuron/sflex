import std.stdio;
import std.file; // nocheckin
import std.array;
import std.typecons;
import std.uni;
import std.conv;
import std.range;
import std.range.primitives;
import std.algorithm;
import std.functional;
import std.traits;
import std.string;
import std.math;
import std.path;

enum TokenType
{
	Unknown,
	CommentLine,
	CommentBlock,
	LiteralString,
	LiteralFloat,
	/* ParenthesisLeft, */
	/* ParenthesisRight, */
	/* BraceLeft, */
	/* BraceRight, */
	/* BracketRight, */
	/* BracketLeft, */
}

struct Token
{
	TokenType type;
	string value; // TODO: https://dlang.org/library/std/sumtype.html
	ulong line;
	ulong column;

	string toString()
	{
		auto value = value.replace("\n", "\\n");
		return i"$(line):$(column): $(type)\t$(value)".text;
	}
}

class Lexer
{
	Appender!(Token[]) tokens;                 // lexical tokens
	string src;                                // source string
	string value;                              // value of token being currently parsed
	ulong line;                                // line offset
	@property ulong column() => offset - bol;  // column offset
	ulong bol;                                 // beginning of line offset
	ulong offset;                              // byte offset

	this(string src)
	{
		this.src = src;
	}

	static assert(isInputRange!Lexer);
	dchar front() => src[offset];
	void popFront()
	{
		if (!empty && front == '\n')
		{
			line++;
			bol = offset + 1;
		}
		offset++;
	}
	bool empty() => src.empty || offset > src.length - 1;
	dchar moveFront() => front;
	int opApply(scope int delegate(dchar) dg)
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
	int opApply(scope int delegate(ulong, dchar) dg)
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
	Nullable!dchar opIndex(long i)
	{
		// underflow
		if (i < 0 && abs(i) > offset)
		{
			return Nullable!dchar.init;
		}

		i += offset;

		// overflow
		if (i > src.length - 1)
		{
			return Nullable!dchar.init;
		}

		return Nullable!dchar(src[i]);
	}

	@property Lexer save() => this;

	string chopWhile(alias pred)()
	{
		Appender!string value;

		while (!empty && pred(front)) 
		{
			value ~= front;
			popFront;
		}

		return value[];
	}

	string chopUntil(alias pred)() => chopWhile!(not!pred);

	string chopLine() => chopUntil!"a=='\\n'";

	Token chopToken(TokenType T)()
	{
		// TODO: break from comptime foreach?
		static foreach (t; __traits(allMembers, TokenType))
		{
			static if (T == mixin("TokenType." ~ t))
			{
				return mixin("chopToken" ~ t);
			}
		}
	}

	Token chopTokenCommentLine()
	{
		Token token;
		token.type = TokenType.Unknown;
		token.line = line;
		token.column = column;
		token.value = chopLine;
		token.value.popFrontExactly(2LU);
		token.type = TokenType.CommentLine;
		return token;
	}

	Token chopTokenCommentBlock()
	{
		Token token;
		token.type = TokenType.Unknown;
		token.line = line;
		token.column = column;

		foreach (_; 0..2)
		{
			token.value ~= front;
			popFront;
		}

		for (;;)
		{
			token.value ~= chopUntil!"a=='/'";
			if (empty)
			{
				break;
			}
			if (this[-1] == '*')
			{
				token.type = TokenType.CommentBlock;
				token.value.popFrontExactly(2LU);
				token.value.popBackExactly(1LU);
				break;
			}
			popFront;
		}

		return token;
	}

	Token chopTokenLiteralString()
	{
		Token token;
		token.type = TokenType.Unknown;
		token.line = line;
		token.column = column;

		token.value ~= front;
		popFront;
		for (;;)
		{
			token.value ~= chopUntil!"a=='\\\''";
			if (empty)
			{
				break;
			}
			else if (this[-1] != '\\')
			{
				token.type = TokenType.LiteralString;
				token.value.popFrontExactly(1LU);
				popFront;
				break;
			}
			else
			{
				token.value ~= front;
			}
			popFront;
		}

		return token;
	}

	Token chopTokenLiteralFloat()
	{
		Token token;
		token.type = TokenType.Unknown;
		token.line = line;
		token.column = column;

		foreach (_; 0..2)
		{
			token.value ~= front;
			popFront;
		}

		token.value ~= chopWhile!isNumber;
		if (this[-1] && this[-1].get.isNumber)
		{
			token.type = TokenType.LiteralFloat;
		}

		return token;
	}


	// TODO: partial/incomplete tokens
	static Token[] tokenize(string src)
	{
		auto l = new Lexer(src);

		foreach (_; l)
		{
			l.chopWhile!isWhite;

			// single-line comment
			if (l[0] == '/' && l[1] == '/')
			{
				auto token = l.chopToken!(TokenType.CommentLine);
				l.tokens ~= token;
			}

			// multi-line comment
			else if (l[0] == '/' && l[1] == '*')
			{
				auto token = l.chopToken!(TokenType.CommentBlock);
				l.tokens ~= token;
			}

			// literal string
			else if (l[0] == '\'')
			{
				auto token = l.chopToken!(TokenType.LiteralString);
				l.tokens ~= token;
			}

			// literal float/decimal/double
			else if (l[0] && l[0].get.isNumber && l[1] == '.')
			{
				auto token = l.chopToken!(TokenType.LiteralFloat);
				l.tokens ~= token;
			}
		}

		return l.tokens[];
	}
}

void main()
{
	auto filePath = "./source/Main.cls";
	auto src = filePath.readText;
	auto tokens = Lexer.tokenize(src);
	tokens.each!writeln;
}
