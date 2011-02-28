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
import flash.system.Security;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.getQualifiedClassName;

	public class Preloader extends Sprite
	{
		public static const START_COMMAND:String = "START";
		
		public static const PAUSE_COMMAND:String = "PAUSE";
		
		public static const CLEAR_COMMAND:String = "CLEAR";
		
		public static const READ_OBJECTS_COMMAND:String = "READ_OBJECTS";
		
		public static const TRACE_METHODS_COMMAND:String = "TRACE_METHODS";
		
		public static const ANALYZE_PERFORMANCE_COMMAND:String = "ANALYZE_PERFORMANCE";
		
		public static const BEGIN_CHUNKED_DATA:String = "BEGIN_CHUNKED_DATA";
		
		public static const END_CHUNKED_DATA:String = "END_CHUNKED_DATA";
		
		private var host:String = "localhost";
		
		private var port:uint = 9998;
		
		private var socket:Socket;
		
		private var savedSamples:Array = [];
		
		private var objects:Dictionary = new Dictionary(true);
		
		private var isSampling:Boolean = false;
		
		public function Preloader()
		{
			super();
			// This only seems to be necessary when the profiler
			// Isn't launched from Flash Builder
			Security.loadPolicyFile("xmlsocket://"+host+":"+port);
			socket = new Socket();
			socket.addEventListener(Event.CONNECT,onConnect);
			socket.addEventListener(ProgressEvent.SOCKET_DATA,onSocketData);
			socket.addEventListener(IOErrorEvent.IO_ERROR,ioError);
			socket.connect(host,port);
			setSamplerCallback(collectSamples);
		}
		
		private function onSocketData(event:ProgressEvent):void {
			pauseSampling();
			
			var data:String = socket.readUTFBytes(socket.bytesAvailable);
			if (data == START_COMMAND) {
				start();
			} else if (data == PAUSE_COMMAND) {
				pause();
			} else if (data == CLEAR_COMMAND) {
				clear();
			} else if (data == READ_OBJECTS_COMMAND) {
				readObjects();
			} else if (data == TRACE_METHODS_COMMAND) {
				traceMethods();
			} else if (data == ANALYZE_PERFORMANCE_COMMAND) {
				analyzePerformance();
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
			
			socket.writeUTFBytes(BEGIN_CHUNKED_DATA);
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
					if (j != s.stack.length-1) {
						socket.writeUTFBytes("  ");
					}
					socket.writeUTFBytes(stackElement.name + ": " + stackElement.file + "["+stackElement.line+"]\n");
				}
			}
			
			socket.flush();
			socket.writeUTFBytes(END_CHUNKED_DATA);
			socket.flush();
			
			if (isSampling) {
				start();
			}
		}
		
		private function analyzePerformance():void {
			collectSamples();
			pauseSampling();
			var i:int;
			var j:int;
			var perfData:Array = [];
			// Keep track of executing methods
			var callStack:Array = [];
			var prevSample:Sample;
			var startTime:Number = NaN;
			for (i=0;i<savedSamples.length;i++) {
				var s:Sample = savedSamples[i] as Sample;
				
				if (isNaN(startTime)) {
					startTime = s.time;
				}
				
				if (s.stack.length < 2) {
					continue;
				}
			
				var methodTime:Number;
				var element:String;
				var timedMethod:Object;
				var stackArray:Array = [];
				var obj:Object;
				var caller:TimedMethod;
				for (j=1;j<s.stack.length-1;j++) {
					var idx1:int = s.stack.length-j;
					var idx2:int = callStack.length - j;
					
					var stackElement:StackFrame = s.stack[idx1];
					if (stackElement == null) {
						continue;
					}
					var label:String = stackElement.toString();
					if (prevSample == null || idx2 < 0) {
						if (callStack.length > 0) {
							caller = callStack[0] as TimedMethod;
						} else {
							caller = null;
						}
						callStack.splice(0,0,new TimedMethod(stackElement,s.stack,s.time,caller));
						continue;
					}
					
					if (idx2 > callStack.length-1) {
						// Should never happen if the code below is correct.
						trace("Whoops!");
					}
					
					var tm:TimedMethod = callStack[idx2] as TimedMethod;
					
					if (tm.stackFrame.toString() == stackElement.toString()) {
						continue;
					}
					
					// Flag the end time for the timed method that was at this position.
					tm.setEnd(s.time);
					
					if (idx2 == callStack.length-1) {
						perfData.push(tm);
					}
					
					// Create a new timed method to place at this position in the call stack
					var ntm:TimedMethod = new TimedMethod(stackElement,s.stack,s.time,tm.caller);
					
					
					// Wind the call stack back and replace anything that isn't in the current stack.
					while (idx2 >= 0) {
						tm = callStack.splice(idx2,1)[0] as TimedMethod;
						tm.setEnd(s.time);
						idx2--;
					}
					
					callStack.splice(0,0,ntm);
					
				}
				
				prevSample = s;
			}
			
			
			socket.writeUTFBytes(BEGIN_CHUNKED_DATA);
			socket.flush();
			
			
			for (i=0;i<perfData.length;i++) {
				tm = perfData[i] as TimedMethod;
				var time:Number = Math.floor((tm.start-startTime)/1000);
				socket.writeUTFBytes(time.toString() + "ms\n");
				socket.writeUTFBytes(readTimedMethod(tm,"  "));
				socket.flush();
			}
			
			
			
			socket.writeUTFBytes(END_CHUNKED_DATA);
			socket.flush();
			
			
			
			if (isSampling) {
				start();
			}
		}
		
		
		private function readTimedMethod(method:TimedMethod,prefix:String = ""):String {
			var s:String = prefix + method.label + " [" + method.duration + "ms]\n";
			var i:int;
			for (i=0;i<method.callees.length;i++) {
				s += readTimedMethod(method.callees[i] as TimedMethod, prefix + "  ");
			}
			return s;
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
			socket.writeUTFBytes(BEGIN_CHUNKED_DATA);
			socket.flush();
			for (i=0;i<nameArray.length;i++) {
				socket.writeUTFBytes(nameArray[i].count + " instances of " + nameArray[i].name + "\n");
			}
			socket.flush();
			socket.writeUTFBytes(END_CHUNKED_DATA);
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
import flash.sampler.StackFrame;

internal class TimedMethod {
	
	public var callees:Array = [];
	
	private var _caller:TimedMethod;
	
	public function set caller(value:TimedMethod):void {
		_caller = value;
		if (value) {
			value.callees.push(this);
		}
	}
	
	public function get caller():TimedMethod {
		return _caller;
	}
	public var start:Number;
	public var end:Number;
	public var duration:Number;
	public var stackFrame:StackFrame;
	public var stack:Array;
	public var label:String;
	
	
	public function TimedMethod(stackFrame:StackFrame,stack:Array,start:Number,caller:TimedMethod) {
		this.stackFrame = stackFrame;
		this.stack = stack;
		this.start = start;
		this.caller = caller;
		if (stackFrame) {
			this.label = stackFrame.toString();
		}
	}
	
	public function setEnd(value:Number):void {
		end = value;
		duration = Math.floor((end - start)/1000);
	}
	
}