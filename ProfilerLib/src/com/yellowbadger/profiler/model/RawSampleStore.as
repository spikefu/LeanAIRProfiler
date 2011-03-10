package com.yellowbadger.profiler.model
{
	import com.yellowbadger.profiler.preloader.IFilter;
	import com.yellowbadger.profiler.preloader.impl.IncludeSampleFilter;
	
	import flash.desktop.IFilePromise;
	import flash.sampler.DeleteObjectSample;
	import flash.sampler.NewObjectSample;
	import flash.sampler.Sample;
	import flash.sampler.StackFrame;
	import flash.sampler.getLexicalScopes;
	import flash.sampler.getMemberNames;
	import flash.utils.Dictionary;

	public class RawSampleStore
	{
		private var inclusionFilters:Array = [];
		
		private var exclusionFilters:Array = [];
		
		private var liveObjects:Dictionary = new Dictionary(true);
		private var samples:Array = [];
		
		
		public function addFilter(filter:IFilter):void {
			if (filter is IncludeSampleFilter) {
				inclusionFilters.push(filter);
			} else {
				exclusionFilters.push(filter);
			}
		}
		
		public function removeFilter(filter:IFilter):void {
			if (filter is IncludeSampleFilter) {
				
			} else {
				
			}
		}
		
		public function removeAllFilters():void {
			inclusionFilters = [];
			exclusionFilters = [];
		}
		
		public function addNewObjectSample(nos:NewObjectSample):void {
			liveObjects[nos.id] = nos;
		}
		
		public function addDeleteObjectSample(dos:DeleteObjectSample):void {
			liveObjects[dos.id] = null;
			delete liveObjects[dos.id];
		}
		
		public function addSample(sample:Sample):void {
			if (!passesFilters(sample)) {
				return;
			}
			if (sample is NewObjectSample) {
				addNewObjectSample(sample as NewObjectSample);
			} else if (sample is DeleteObjectSample) {
				addDeleteObjectSample(sample as DeleteObjectSample);
			} else {
				
			}
		}
		
		public function findLoiteringObjects():String {
			var i:int = 0;
			var s:String = "";
			for each (var nos:NewObjectSample in liveObjects) {
				if (nos.object){
					s += nos.object + "\n";
				}
				s += "Object Stack:" + i + "\n";
				i++;
				if (nos.stack) {
					for each (var frame:StackFrame in nos.stack) {
						s += frame.toString() + "\n";
					}
				}
				s += "\n\n";
				
			}
			return s;
		}
		
		private function passesFilters(sample:Sample):Boolean {
			var i:int;
			var filter:IFilter;
			
			for each (filter in inclusionFilters) {
				if (!filter.pass(sample)) {
					return false;
				}
			}
			
			for each (filter in exclusionFilters) {
				if (!filter.pass(sample)) {
					return false;
				}
			}
			
			return true;
		}
		
	}
}