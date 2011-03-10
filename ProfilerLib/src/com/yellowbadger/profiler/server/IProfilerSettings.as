package com.yellowbadger.profiler.server
{
	public interface IProfilerSettings
	{
		function get autoStart():Boolean;
		function set autoStart(value:Boolean):void;
	}
}