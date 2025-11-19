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

enum TokenType
{
	CommentSingleLine,
	CommentMultiLine,
	Identifier,
	/* ParenthesisLeft, */
	/* ParenthesisRight, */
	/* BraceLeft, */
	/* BraceRight, */
	/* BracketRight, */
	/* BracketLeft, */
	/* CommentMultiLine, */
}

struct Token
{
	TokenType type;
	string value;
	ulong line;
	ulong column;

	string toString()
	{
		return i"$(type)(value=$(value), line=$(line), column=$(column))".text;
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
		offset++;
	}
	auto empty() => offset >= src.length - 1; // FIXME: this is probably wrong
	auto length() => src.length - 1 - offset;
	auto opIndex(ulong i) => src[offset + i];

	string chopWhile(alias pred)()
	{
		Appender!string value;

		while (!empty && pred(front)) 
		{
			if (front == '\n')
			{
				line++;
				bol = offset + 1;
			}
			value ~= front;
			popFront;
		}

		return value[];
	}

	string chopUntil(alias pred)()
	{
		return chopWhile!(not!pred);
	}

	string chopLine()
	{
		scope(exit)
		{
			line++;
			bol = offset + 1;
		}
		return chopUntil!"a=='\\n'";
	}

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

	Token chopTokenCommentSingleLine()
	{
		Token token;
		token.type = TokenType.CommentSingleLine;
		token.line = line;
		token.column = column;
		token.value = chopLine;
		return token;
	}

	Token chopTokenCommentMultiLine()
	{
		Token token;
		token.type = TokenType.CommentMultiLine;
		token.line = line;
		token.column = column;
		token.value ~= front;

		while (!empty)
		{
			token.value ~= chopUntil!"a=='/'";
			if (this[-1] == '*')
			{
				token.value ~= front;
				break;
			}
			popFront;
		}
		token.value = token.value.lineSplitter.join("\\n");

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
				auto token = l.chopToken!(TokenType.CommentSingleLine);
				l.tokens ~= token;
			}

			// multi-line comment
			else if (l[0] == '/' && l[1] == '*')
			{
				auto token = l.chopToken!(TokenType.CommentMultiLine);
				l.tokens ~= token;
			}
		}

		return l.tokens[];
	}
}

void main()
{
	auto file = "./source/Main.cls";
	auto src = file.readText;
	auto tokens = Lexer.tokenize(src);
	writeln;
	writeln("Tokens:");
	tokens.each!(token => writeln('\t', token));
}
