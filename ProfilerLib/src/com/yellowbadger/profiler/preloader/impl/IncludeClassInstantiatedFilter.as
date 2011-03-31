package com.yellowbadger.profiler.preloader.impl
{
	import flash.sampler.DeleteObjectSample;
	import flash.sampler.NewObjectSample;
	import flash.sampler.Sample;
	import flash.sampler.StackFrame;
	import flash.sampler.getLexicalScopes;
	import flash.sampler.getMemberNames;

	public class IncludeClassInstantiatedFilter extends IncludeSampleFilter
	{
		private var firstLineOnly:Boolean = false;
		
		public function IncludeClassInstantiatedFilter(filter:String,firstLineOnly:Boolean)
		{
			super(filter);
			firstLineOnly = firstLineOnly;
		}
		
		override public function pass(sample:Sample):Boolean {
			// can't analyze delete object samples, so just let them
			// through so the corresponding new object sample is cleaned up.
			if (sample is DeleteObjectSample) {
				return true;
			}
			if (sample is NewObjectSample) {
				var nos:NewObjectSample = sample as NewObjectSample;
				var details:Array = [];
				var goodMatch:Boolean = false;
				if (nos.stack && nos.stack.length > 0) {
					for each (var frame:StackFrame in nos.stack) {
						var s:String = frame.toString();
						if (frame.name.indexOf(filter) >= 0) {
							goodMatch = true;
						}
						if (firstLineOnly) {
							break;
						}
					}
					if (!goodMatch) {
						return false;
					}
				}
				return goodMatch;
			}
			return false;
		}
	}
}