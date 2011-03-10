package com.yellowbadger.profiler.preloader
{
	public interface IProfilerClientConnection
	{
		function send(str:String):void;
		function connected():Boolean;
	}
}