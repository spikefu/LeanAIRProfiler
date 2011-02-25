package {

import flash.display.MovieClip;
import flash.display.Sprite;
import flash.errors.IOError;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.net.Socket;
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
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.getQualifiedClassName;

	public class Preloader extends Sprite
	{
		private var socket:Socket;
		
		private var savedSamples:Array = [];
		
		private var objects:Dictionary = new Dictionary(true);
		
		private var isSampling:Boolean = false;
		
		public function Preloader()
		{
			super();
			socket = new Socket();
			socket.addEventListener(Event.CONNECT,onConnect);
			socket.addEventListener(ProgressEvent.SOCKET_DATA,onSocketData);
			socket.addEventListener(IOErrorEvent.IO_ERROR,ioError);
			socket.connect("localhost",9998);
			setSamplerCallback(collectSamples);
		}
		
		private function onSocketData(event:ProgressEvent):void {
			pauseSampling();
			
			var data:String = socket.readUTFBytes(socket.bytesAvailable);
			if (data == "START") {
				start();
			} else if (data == "PAUSE") {
				pause();
			} else if (data == "CLEAR") {
				clear();
			} else if (data == "READ_OBJECTS") {
				readObjects();
			} else if (data == "TRACE_METHODS") {
				traceMethods();
			}
			if (isSampling) {
				start();
			}
		}
		
		private function ioError(event:IOErrorEvent):void {
			// Just swallow the error
			// This happens when the LeanAirProfiler launches if the Preloader.swf is in mm.cfg
			// It also happens if LeanAirProfiler isn't running or listening and Preloader.swf is in mm.cfg
		}
		
		/**
		 * OK, let's rock this joint and collect some numbers
		 */
		private function start():void {
			startSampling();
			isSampling = true;
		}
		
		/**
		 * Whoah there! let's take a break.
		 */
		private function pause():void {
			pauseSampling();
			isSampling = false;
		}
		
		/**
		 * Reset the objects collection and clear anything the sampler API has
		 * stored internally.
		 */
		private function clear():void {
			pauseSampling();
			
			objects = new Dictionary(true);
			savedSamples = [];
			clearSamples();
			if (isSampling) {
				start();
			}
		}
		
		/**
		 * Let's find us some lingering objects.
		 * Add any NewObjectSample without a corresponding
		 * DeleteObjectSample to the objects collection, then
		 * clear the internal samples.
		 */
		private function collectSamples():void {
			pauseSampling();
			var samples:* = getSamples();
			var name:String;
			for each (var s:Sample in samples ) {
				if (s is NewObjectSample) {
					var nos:NewObjectSample = s as NewObjectSample;
					objects[nos.id] = s;
					
				} else if (s is DeleteObjectSample) {
					var dos:DeleteObjectSample = s as DeleteObjectSample;
					if (objects[dos.id]) {
						delete objects[dos.id];
					}
				} else {
					savedSamples.push(s);
				}
			}
			
			clearSamples();
			if (isSampling) {
				start();
			}
		}
		
		/**
		 * 
		 */
		private function traceMethods():void {
			collectSamples();
			pauseSampling();
			var i:int;
			var j:int;
			
			socket.writeUTFBytes("BEGIN_CHUNKED_DATA");
			socket.flush();
			var startTime:Number = -1;
			for (i=0;i<savedSamples.length;i++) {
				var s:Sample = savedSamples[i] as Sample;
				if (startTime == -1) {
					startTime = s.time;
				}
				if (s.stack.length < 2) {
					continue;
				}
				var delta:Number = Math.floor((s.time - startTime)/1000); 
				socket.writeUTFBytes("\ntime:" + delta + "ms\n");
				for (j=0;j<s.stack.length;j++) {
					var stackElement:StackFrame = s.stack[j];
					if (stackElement == null) {
						continue;
					}
					if (i>0) {
						socket.writeUTFBytes("  ");
					}
					socket.writeUTFBytes(stackElement.name + ": " + stackElement.file + "["+stackElement.line+"]\n");
				}
			}
			
			socket.flush();
			socket.writeUTFBytes("END_CHUNKED_DATA");
			socket.flush();
			
			if (isSampling) {
				start();
			}
		}
		
		private function readObjects():void {
			pauseSampling();
			
			collectSamples();
			var nos:NewObjectSample;
			var names:Dictionary = new Dictionary(true);
			var nameArray:Array = [];
			for each (nos in objects) {
				var name:String = getQualifiedClassName(nos.type);
				if (!names[name]) {
					names[name] = 0;
				}
				names[name]++;
			}
			var s:String;
			for (s in names) {
				nameArray.push({name:s,count:names[s]});
			}
			nameArray = nameArray.sortOn("count",Array.DESCENDING | Array.NUMERIC);
			var i:int;
			socket.writeUTFBytes("BEGIN_CHUNKED_DATA");
			socket.flush();
			for (i=0;i<nameArray.length;i++) {
				socket.writeUTFBytes(nameArray[i].count + " instances of " + nameArray[i].name + "\n");
			}
			socket.flush();
			socket.writeUTFBytes("END_CHUNKED_DATA");
			socket.flush();
			
			if (isSampling) {
				start();
			}
		}
		
		private function onConnect(event:Event):void {
			pauseSampling();

			socket.writeUTFBytes("Preload profiler connected!");

			if (isSampling) {
				start();
			}
		}
	}
}