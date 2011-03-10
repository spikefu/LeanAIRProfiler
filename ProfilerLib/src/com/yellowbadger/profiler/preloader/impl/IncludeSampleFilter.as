package com.yellowbadger.profiler.preloader.impl
{
	import com.yellowbadger.profiler.preloader.IFilter;
	
	import flash.sampler.Sample;
	
	public class IncludeSampleFilter implements IFilter
	{
		public var filter:String;
		
		public function IncludeSampleFilter(filter:String)
		{
			this.filter = filter;
		}
		
		public function pass(sample:Sample):Boolean
		{
			return false;
		}
		
		
		public function equals(filter:IFilter):Boolean {
			if (filter == null) {
				return false;
			}
			if (!(filter is IncludeSampleFilter)) {
				return false;
			}
			if ((filter as IncludeSampleFilter).filter == this.filter) {
				return true;
			}
			return false;
		}
		
	}
}