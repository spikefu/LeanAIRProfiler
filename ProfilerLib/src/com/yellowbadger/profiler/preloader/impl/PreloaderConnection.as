package com.yellowbadger.profiler.preloader.impl
{
	import com.yellowbadger.profiler.ProtocolConstants;
	import com.yellowbadger.profiler.model.RawSampleStore;
	import com.yellowbadger.profiler.preloader.IProfilerClientConnection;
	import com.yellowbadger.profiler.preloader.ISampler;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.sampler.DeleteObjectSample;
	import flash.sampler.NewObjectSample;
	import flash.sampler.Sample;
	import flash.sampler.StackFrame;
	import flash.system.Security;
	import flash.system.System;
	import flash.utils.flash_proxy;

	public class PreloaderConnection implements IProfilerClientConnection
	{
		
		private var port:Number;
		private var host:String;
		private var socket:Socket;
		public var sampler:ISampler;
		private var store:RawSampleStore;
		private var writer:SampleWriter;
		
		public function PreloaderConnection(host:String,port:Number)
		{
			this.port = port;
			this.host = host;
			writer =  new SampleWriter(this);
			store = new RawSampleStore();
			sampler = new SampleCollector(store);
			connect();
		}
		
		public function connected():Boolean {
			return socket.connected;
		}
		
		public function send(str:String):void {
			if (socket.connected) {
				socket.writeUTFBytes(str);
			}
		}
		
		private function connect():void {
			// This only seems to be necessary when the profiler
			// Isn't launched from Flash Builder
			Security.loadPolicyFile("xmlsocket://"+host+":"+port);
			socket = new Socket();
			socket.addEventListener(Event.CONNECT,onConnect);
			socket.addEventListener(ProgressEvent.SOCKET_DATA,onSocketData);
			socket.addEventListener(IOErrorEvent.IO_ERROR,ioError);
			socket.connect(host,port);
		}
		
		
		
		private function onSocketData(event:ProgressEvent):void {
			sampler.pause();
			
			var data:String = socket.readUTFBytes(socket.bytesAvailable);
			if (data == ProtocolConstants.START_COMMAND) {
				sampler.start();
			} else if (data == ProtocolConstants.PAUSE_COMMAND) {
				sampler.pause();
			} else if (data == ProtocolConstants.CLEAR_COMMAND) {
				sampler.clear();
			} else if (data == ProtocolConstants.FIND_LOITERING_OBJECTS) {
				findLoiteringObjects();
			} else if (data.indexOf(ProtocolConstants.WATCH) == 0) {
				watch(data)
			} else {
				trace("Unknown command: " + data);
			}
			if (sampler.isSampling()) {
				sampler.start();
			}
		}
		
		private function findLoiteringObjects():void {
			System.gc();
			sampler.collectSamples();
			var result:String = store.findLoiteringObjects();
			socket.writeUTFBytes(ProtocolConstants.BEGIN_CHUNKED_DATA);
			socket.flush();
			socket.writeUTFBytes("Loitering objects:\n");
			socket.writeUTFBytes(result);
			socket.writeUTFBytes(ProtocolConstants.END_CHUNKED_DATA);
			socket.flush();
		}
		
		private function watch(cmd:String):void {
			var parts:Array = cmd.split("-");
			if (parts[1] != null) {
				store.removeAllFilters();
				store.addFilter(new IncludeClassInstantiatedFilter(parts[1]));
			}
		}
		
		private function ioError(event:IOErrorEvent):void {
			// Just swallow the error
			// This happens when the LeanAirProfiler launches if the Preloader.swf is in mm.cfg
			// It also happens if LeanAirProfiler isn't running or listening and Preloader.swf is in mm.cfg
		}
		
		
		private function onConnect(event:Event):void {
			sampler.pause();
			
			socket.writeUTFBytes("Preload profiler connected!");
			
			if (sampler.isSampling()) {
				sampler.start();
			}
		}
	}
}