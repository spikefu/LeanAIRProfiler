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
		public function IncludeClassInstantiatedFilter(filter:String)
		{
			super(filter);
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
					var frame:StackFrame = nos.stack[0] as StackFrame;
					var s:String = frame.toString();
					if (frame.toString().indexOf(filter) >= 0) {
						goodMatch = true;
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