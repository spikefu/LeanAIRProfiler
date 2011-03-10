package {

import com.yellowbadger.profiler.preloader.impl.PreloaderConnection;

import flash.display.MovieClip;
import flash.display.Sprite;
import flash.errors.IOError;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.net.Socket;
import flash.sampler.setSamplerCallback;
import flash.sampler.startSampling;
import flash.system.Security;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;
import flash.utils.getQualifiedClassName;

	public class Preloader extends Sprite
	{
		
		private var connection:PreloaderConnection;
		private var host:String = "localhost";
		
		private var port:uint = 9998;
		
		public function Preloader()
		{
			super();
			this.connection = new PreloaderConnection(host,port);
			setSamplerCallback(connection.sampler.collectSamples);
			startSampling();
			addEventListener(Event.REMOVED_FROM_STAGE,removedFromStage);
			addEventListener(Event.ADDED_TO_STAGE,addedToStage);
		}
		
		
		private function addedToStage(event:Event):void {
			
		}
		
		
		private function removedFromStage(event:Event):void {
			
		}

		
		/**
		 * 
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
				socket.writeUTFBytes("\nNew method call @"+time+"ms \n");
				socket.writeUTFBytes(readTimedMethod(tm,startTime,"  "));
				socket.flush();
			}
			
			
			
			socket.writeUTFBytes(END_CHUNKED_DATA);
			socket.flush();
			
			
			
			if (isSampling) {
				start();
			}
		}
		
		
		private function readTimedMethod(method:TimedMethod,startTime:Number,prefix:String = ""):String {
			var offset:Number = Math.floor((method.start - startTime)/1000)
			var s:String = method.duration + "ms" + prefix + method.stackFrame.name +":"+method.stackFrame.line + "startTime:"+method.start+"|endTime:" + method.end +"\n";
			var i:int;
			for (i=0;i<method.callees.length;i++) {
				s += readTimedMethod(method.callees[i] as TimedMethod,startTime, prefix + "  ");
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
		
		 */
	}
}
/*
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
*/