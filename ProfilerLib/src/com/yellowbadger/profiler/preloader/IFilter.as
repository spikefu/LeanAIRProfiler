package com.yellowbadger.profiler.preloader
{
	import flash.sampler.Sample;

	public interface IFilter
	{
		function pass(sample:Sample):Boolean;
		function equals(filter:IFilter):Boolean;
	}
}