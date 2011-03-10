package com.yellowbadger.profiler.server
{
	public interface IProfilerServerConnection
	{
		function get connected():Boolean;
		function listen():void;
		function close():void;
	}
}