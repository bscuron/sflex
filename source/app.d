import sflex;
import std.stdio;
import std.parallelism;
import std.range;
import std.mmfile;
import std.file;
import std.algorithm;
import std.conv;
import std.container;
import std.functional;

void main(string[] args)
{

	Appender!string paths;
	foreach (arg; args.dropOne)
	{
		if (arg.isFile)
		{
			synchronized
			{
				paths ~= arg;
				paths ~= '\0';
			}
		}
		else
		{
			foreach (dirEntry; dirEntries(arg, "*.{cls,trigger,apex}", SpanMode.depth).parallel)
			{
				if (dirEntry.isFile)
				{
					synchronized
					{
						paths ~= dirEntry.name;
						paths ~= '\0';
					}
				}
			}
		}
	}

	Appender!string buffer;
	foreach (path; paths[].splitter('\0').dropBackOne.parallel)
	{
		auto tokens = tokenize!MmFile(path);
		synchronized
		{
			foreach (token; tokens)
			{
				buffer ~= path;
				buffer ~= ':';
				buffer ~= (token.line + 1).to!string;
				buffer ~= ':';
				buffer ~= (token.column + 1).to!string;
				buffer ~= '|';
				buffer ~= token.type.to!string;
				buffer ~= '|';
				buffer ~= token.value;
				buffer ~= '\n';
			}
		}
	}

	buffer[].write;
}
