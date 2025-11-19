import std.stdio;
import std.file; // nocheckin
import std.array;
import std.typecons;
import std.uni;
import std.conv;
import std.range;
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
	string value;
	ulong line;
	ulong column;

	string toString()
	{
		auto value = this.value.lineSplitter.join("\\n");
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

	static assert(isInputRange!(Lexer));
	auto front() => src[offset];
	auto popFront()
	{
		if (!empty && front == '\n')
		{
			line++;
			bol = offset + 1;
		}
		offset++;
	}
	auto empty() => offset > src.length - 1;

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
		popFront; // pop '/'
		popFront; // pop '/'
		token.value = chopLine; // chop until '\n'
		token.type = TokenType.CommentLine;
		return token;
	}

	Token chopTokenCommentBlock()
	{
		Token token;
		token.type = TokenType.Unknown;
		token.line = line;
		token.column = column;

		popFront; // pop '/'
		popFront; // pop '*'

		for (;;)
		{
			token.value ~= chopUntil!"a=='/'"; // chop until '/'
			if (empty)
			{
				break;
			}
			if (this[-1] == '*')
			{
				token.value.popBack; // pop '*' from token value
				token.type = TokenType.CommentBlock;
				popFront; // pop '/'
				break;
			}
			token.value ~= front; // chop comment char
			popFront; // pop comment char
		}

		return token;
	}

	Token chopTokenLiteralString()
	{
		Token token;
		token.type = TokenType.Unknown;
		token.line = line;
		token.column = column;
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
