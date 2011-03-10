package com.yellowbadger.profiler.preloader.impl
{
	
	import flash.sampler.Sample;
	import flash.sampler.StackFrame;

	public class PreloaderPackageFilter extends IncludeSampleFilter
	{
		public function PreloaderPackageFilter(filter:String)
		{
			super(filter);
		}
		
		override public function pass(sample:Sample):Boolean {
			if (sample.stack) {
				for each (var frame:StackFrame in sample.stack) {
					if (frame.toString().indexOf(filter) >=0 ) {
						return false;
					}
				}
			}
			return true;
		}
		
	}
}