package com.yellowbadger.profiler.preloader.impl
{
	import com.yellowbadger.profiler.preloader.IProfilerClientConnection;
	import com.yellowbadger.profiler.preloader.ISampleWriter;
	
	import flash.net.Socket;
	import flash.sampler.DeleteObjectSample;
	import flash.sampler.NewObjectSample;
	import flash.sampler.Sample;
	import flash.sampler.StackFrame;
	import flash.utils.ByteArray;

	public class SampleWriter implements ISampleWriter
	{
		private var connection:IProfilerClientConnection;
		
		public function SampleWriter(connection:IProfilerClientConnection)
		{
			this.connection = connection;
		}
		
		
		private function writeNewObjectSample(nos:NewObjectSample):void {
			
		}
		
		private function writeDeletedObjectSample(dos:DeleteObjectSample):void {
			
		}
		
		public function writeSample(sample:Sample):void {
			if(sample is NewObjectSample) {
				writeNewObjectSample(sample as NewObjectSample);
			} else if (sample is DeleteObjectSample) {
				writeDeletedObjectSample(sample as DeleteObjectSample);
			}
			
		}
		
		private function writeStackTrace(stack:Array):void {
			
		}
		
		private function writeStackFrame(frame:StackFrame):void {
			
		}
		
	}
}