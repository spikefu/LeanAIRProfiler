package com.yellowbadger.profiler.preloader
{
	public interface ISampler
	{
		function start():void;
		function pause():void;
		function clear():void;
		function isSampling():Boolean;
		function collectSamples():void;
	}
}