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

import org.osmf.events.TimeEvent;

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
		}
		
		private function start():void {
			startSampling();
			isSampling = true;
		}
		
		private function pause():void {
			pauseSampling();
			isSampling = false;
		}
		
		private function clear():void {
			pauseSampling();
			
			objects = new Dictionary(true);
			clearSamples();
			if (isSampling) {
				start();
			}
		}
		
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
					if (Math.random() < 0.005 && s.stack) {
						//readSample(s);
					}
				}
			}
			
			clearSamples();
			if (isSampling) {
				start();
			}
		}

		private function traceMethods():void {
			pauseSampling();
			
			var i:int;
			
			var samples:* = getSamples();
			
			socket.writeUTFBytes("BEGIN_CHUNKED_DATA");
			socket.flush();
			for each (var s:Sample in samples ) {
				if (s is NewObjectSample || s is DeleteObjectSample) {
					continue;
				}
				if (s.stack.length < 2) {
					continue;
				}
				var d:Date = new Date(s.time/1000);
				socket.writeUTFBytes("\ntime:" + d.minutes + ":" + d.seconds + "." + d.milliseconds + "\n");
				for (i=0;i<s.stack.length;i++) {
					var stackElement:StackFrame = s.stack[i];
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

			socket.writeUTFBytes("LeanProfiler connected!");

			if (isSampling) {
				start();
			}
		}
	}
}