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
import std.concurrency;
import std.typecons;
import core.stdc.stdio;
import core.memory;

void main(string[] args)
{
	Appender!(typeof(task!(tokenize!MmFile)(string.init))[]) tasks;
	foreach (arg; args.dropOne)
	{
		if (arg.isFile)
		{
			auto task = task!(tokenize!MmFile)(arg);
			tasks ~= task;
			taskPool.put(task);
		}
		else foreach (dirEntry; dirEntries(arg, "*.{cls,trigger,apex}", SpanMode.depth).parallel)
		{
			auto task = task!(tokenize!MmFile)(dirEntry.name);
			tasks ~= task;
			taskPool.put(task);
		}
	}

	Appender!(char[]) buffer;
	foreach (task; tasks)
	{
		auto tokens = task.yieldForce();
		foreach (token; tokens)
		{
			buffer ~= token.line.to!string;
			buffer ~= ":";
			buffer ~= token.column.to!string;
			buffer ~= "|";
			buffer ~= token.type.memoize!(to!string);
			buffer ~= "|";
			buffer ~= token.value;
			buffer ~= "\n";
		}
		buffer[].write;
		buffer.clear;
	}
}
