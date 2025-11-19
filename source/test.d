import sflex;
import std.range;
import std.conv;
import std.stdio;
import std.algorithm.comparison;
import std.algorithm;

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
	assert(token.value == "// single-line comment");
}

unittest
{
	auto src = "/* single-line block comment */";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.CommentBlock);
	assert(token.value == "/* single-line block comment */");
}

unittest
{
	auto src = "/*\n * multi-line block comment\n */";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.CommentBlock);
	assert(token.value == "/*\n * multi-line block comment\n */");
}

unittest
{
	auto src = "123456789";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.LiteralInteger);
	assert(token.value == "123456789");
}

unittest
{
	auto src = "3.14159";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto token = tokens.front;
	assert(token.type == TokenType.LiteralFloat);
	assert(token.value == "3.14159");
}

unittest
{
	auto src = ".1234";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 2);
	auto first = tokens.front;
	tokens.popFront;
	assert(first.type == TokenType.PunctuationDot);
	auto second = tokens.front;
	tokens.popFront;
	assert(second.type == TokenType.LiteralInteger);
	assert(second.value == "1234");
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
	auto second = tokens.front;
	tokens.popFront;
	assert(second.type == TokenType.PunctuationDot);
	auto third = tokens.front;
	tokens.popFront;
	assert(third.type == TokenType.LiteralInteger);
	assert(third.value == "123");
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
	auto second = tokens.front;
	tokens.popFront;
	assert(second.type == TokenType.PunctuationDot);
	auto third = tokens.front;
	tokens.popFront;
	assert(third.type == TokenType.LiteralInteger);
	assert(third.value == "123");
}

unittest
{
	auto src = "a++";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 3);
	auto first = tokens.front;
	tokens.popFront;
	assert(first.type == TokenType.Identifier);
	assert(first.value == "a");
	auto second = tokens.front;
	tokens.popFront;
	assert(second.type == TokenType.PunctuationPlus);
	auto third = tokens.front;
	tokens.popFront;
	assert(third.type == TokenType.PunctuationPlus);
}

unittest
{
	auto src = " \r\r\n\t";
	auto tokens = tokenize!string(src);
	assert(tokens.empty);
}

unittest
{
	auto src = "PUBLIC";
	auto tokens = tokenize!string(src);
	assert(tokens.length == 1);
	auto first = tokens.front;
	assert(first.type == TokenType.Keyword);
}
