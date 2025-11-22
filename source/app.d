import lexer;
import std.stdio;
import std.parallelism;
import std.string;
import std.range;
import std.mmfile;
import std.file;
import std.datetime.stopwatch;
import std.algorithm;
import std.conv;

void main(string[] args)
{
	Appender!string output;
	output.reserve(1024LU * 1000LU);
	foreach (filePath; args.dropOne.parallel)
	{
		auto tokens = filePath.tokenize!MmFile;
		foreach (token; tokens)
		{
			synchronized
			{
				output ~= i"$(filePath):$(token.line+1):$(token.column+1)|$(token.type)|$(token.value[])\n".text;
			}
		}
	}
	write(output[]);
}

unittest
{
	auto src = "";
	auto tokens = tokenize!string(src);
	assert(tokens.empty);
}

unittest
{
	auto src = "// single-line comment";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.CommentLine);
	assert(token.value == src);
	assert(token.line == 0LU);
	assert(token.column == 0LU);
}

unittest
{
	auto src = "/* single-line block comment */";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.CommentBlock);
	assert(token.value == src);
	assert(token.line == 0LU);
	assert(token.column == 0LU);
}

unittest
{
	auto src = "/*\n";
	     src ~=" * multi-line block comment\n";
	     src ~=" */";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.CommentBlock);
	assert(token.value == src);
	assert(token.line == 0LU);
	assert(token.column == 0LU);
}

unittest
{
	auto src = "69420";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.LiteralInteger);
	assert(token.value == src);
	assert(token.line == 0LU);
	assert(token.column == 0LU);
}

unittest
{
	auto src = "1.234";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.LiteralFloat);
	assert(token.value == src);
	assert(token.line == 0LU);
	assert(token.column == 0LU);
}

unittest
{
	auto src = ".234";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 2);
	auto first = tokens.front;
	tokens.popFront;
	assert(first.type == TokenType.PunctuationDot);
	assert(first.line == 0LU);
	assert(first.column == 0LU);
	auto second = tokens.front;
	tokens.popFront;
	assert(second.type == TokenType.LiteralInteger);
	assert(second.value == src.dropOne);
	assert(second.line == 0LU);
	assert(second.column == 1LU);
}

unittest
{
	auto src = "123.321.123";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 3);
	auto first = tokens.front;
	tokens.popFront;
	assert(first.type == TokenType.LiteralFloat);
	assert(first.value == "123.321");
	assert(first.line == 0LU);
	assert(first.column == 0LU);
	auto second = tokens.front;
	tokens.popFront;
	assert(second.type == TokenType.PunctuationDot);
	assert(second.line == 0LU);
	assert(second.column == first.value.length);
	auto third = tokens.front;
	tokens.popFront;
	assert(third.type == TokenType.LiteralInteger);
	assert(third.value == "123");
	assert(third.line == 0LU);
	assert(third.column == first.value.length + 1);
}
