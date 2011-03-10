package com.yellowbadger.profiler.preloader.impl
{
	import com.yellowbadger.profiler.model.RawSampleStore;
	import com.yellowbadger.profiler.preloader.ISampleWriter;
	import com.yellowbadger.profiler.preloader.ISampler;
	
	import flash.events.TimerEvent;
	import flash.sampler.DeleteObjectSample;
	import flash.sampler.NewObjectSample;
	import flash.sampler.Sample;
	import flash.sampler.StackFrame;
	import flash.sampler.clearSamples;
	import flash.sampler.getSampleCount;
	import flash.sampler.getSamples;
	import flash.sampler.pauseSampling;
	import flash.sampler.setSamplerCallback;
	import flash.sampler.startSampling;
	import flash.sampler.stopSampling;
	import flash.utils.Timer;
	
	public class SampleCollector implements ISampler
	{
		private var sampling:Boolean = false;
		
		private var store:RawSampleStore;
		
		public function SampleCollector(store:RawSampleStore) {
			this.store = store;
			setSamplerCallback(collectSamples);
		}
		
		
		/**
		 * OK, let's rock this joint and collect some numbers
		 */
		public function start():void {
			startSampling();
			sampling = true;
		}
		
		/**
		 * Whoah there! let's take a break.
		 */
		public function pause():void {
			pauseSampling();
			sampling = false;
		}
		
		public function isSampling():Boolean {
			return sampling;
		}
		
		
		
		/**
		 * clear anything the sampler API has
		 * stored internally.
		 */
		public function clear():void {
			pauseSampling();
			clearSamples();
			if (sampling) {
				start();
			}
		}
		
		
		
		
		/**
		 * Let's find us some lingering objects.
		 * Add any NewObjectSample without a corresponding
		 * DeleteObjectSample to the objects collection, then
		 * clear the internal samples.
		 */
		public function collectSamples():void {
			pauseSampling();
			var samples:* = getSamples();
			var name:String;
			for each (var s:Sample in samples ) {
				store.addSample(s);
			}
			
			clearSamples();
			if (sampling) {
				start();
			}
		}
		
		
	}
}