package com.yellowbadger.profiler.preloader
{
	import flash.sampler.DeleteObjectSample;
	import flash.sampler.NewObjectSample;
	import flash.sampler.Sample;

	public interface ISampleWriter
	{
		function writeSample(sample:Sample):void;
	}
}