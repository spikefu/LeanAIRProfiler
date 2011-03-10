package com.yellowbadger.profiler.server.impl
{
	import com.yellowbadger.profiler.CommandLineArgs;
	import com.yellowbadger.profiler.ProtocolConstants;
	import com.yellowbadger.profiler.model.ProcessedSampleStore;
	import com.yellowbadger.profiler.model.RawSampleStore;
	import com.yellowbadger.profiler.server.IProfilerLog;
	import com.yellowbadger.profiler.server.IProfilerServerConnection;
	import com.yellowbadger.profiler.server.IProfilerSettings;
	import com.yellowbadger.profiler.util.MMCfgUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.utils.ByteArray;

	public class ServerConnection extends EventDispatcher implements IProfilerServerConnection
	{
		
		public static const CONNECTION_STATE_CHANGED:String = "connectionStateChanged";
		
		private var port:Number;
		
		private var buffer:String;
		
		private var buffering:Boolean;
		
		private var serverSocket:ServerSocket;
		
		private var clientSocket:Socket;
		
		[Bindable]
		public var listening:Boolean;
		
		private var log:Function;
		
		[Bindable]
		public var profiling:Boolean;
		
		private var settings:IProfilerSettings;
		
		private var store:ProcessedSampleStore;
		
		public function ServerConnection(port:Number,log:Function,settings:IProfilerSettings,store:ProcessedSampleStore)
		{
			this.port = port;
			this.log = log;
			this.settings = settings;
			this.store = store;
			reset();
		}
		
		public function reset():void {
			if (serverSocket) {
				serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT,onConnect);
			}
			serverSocket = new ServerSocket();
			serverSocket.bind(port);
			serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT,onConnect);
			
		}
		
		[Bindable("connectionStateChanged")]
		public function get connected():Boolean {
			return clientSocket && clientSocket.connected;
		}
		
		public function listen():void {
			serverSocket.listen();
			MMCfgUtil.writePreloaderConfig(CommandLineArgs.preloaderPath);
			listening = true;
		}
		
		public function close():void {
			serverSocket.close();
			reset();
			MMCfgUtil.clearPreloaderConfig(CommandLineArgs.preloaderPath);
			listening = false;
		}
		
		private function onConnect(event:ServerSocketConnectEvent):void {
			clientSocket = event.socket;
			clientSocket.addEventListener( ProgressEvent.SOCKET_DATA, onClientSocketData );
			clientSocket.addEventListener(Event.CLOSE,onClientClose);
			clientSocket.addEventListener(Event.DEACTIVATE,onClientDeactivate);
			log( "Connection from " + clientSocket.remoteAddress + ":" + clientSocket.remotePort );
			dispatchEvent(new Event(CONNECTION_STATE_CHANGED));
			MMCfgUtil.clearPreloaderConfig(CommandLineArgs.preloaderPath);
			if (settings.autoStart) {
				startProfiling();
			}
		}
		
		private function onClientClose(event:Event):void {
			dispatchEvent(new Event(CONNECTION_STATE_CHANGED));
			MMCfgUtil.clearPreloaderConfig(CommandLineArgs.preloaderPath);
			listening = false;
		}
		
		private function onClientDeactivate(event:Event):void {
			
		}
		
		
		public function startProfiling():void {
			if (connected) {
				clientSocket.writeUTFBytes(ProtocolConstants.START_COMMAND);
				clientSocket.flush();
				profiling = true;
			}
		}
		
		public function pauseProfiling():void {
			if (connected) {
				clientSocket.writeUTFBytes(ProtocolConstants.PAUSE_COMMAND);
				clientSocket.flush();
			}
			profiling = false;
		}
		
		public function findLoiteringObjects():void {
			if (connected) {
				clientSocket.writeUTFBytes(ProtocolConstants.FIND_LOITERING_OBJECTS);
				clientSocket.flush();
			}
		}
		
		public function watchClass(name:String):void {
			if (connected) {
				clientSocket.writeUTFBytes(ProtocolConstants.WATCH + "-" + name + "-");
				clientSocket.flush();
			}
		}
		
		
		public function clearProfilingData():void {
			if (connected) {
				clientSocket.writeUTFBytes(ProtocolConstants.CLEAR_COMMAND);
				clientSocket.flush();
				profiling = false;
				log("Profiling data cleared.");
			}
		}
		
		private function onClientSocketData( event:ProgressEvent ):void
		{
			var s:String = clientSocket.readUTFBytes(clientSocket.bytesAvailable);
			if (s.indexOf(ProtocolConstants.POLICY_FILE_REQUEST) == 0) {
				sendCrossDomainPolicy();
				return;
			}
			var idx:int = 0;
			if (s.indexOf(ProtocolConstants.BEGIN_CHUNKED_DATA) == 0) {
				buffer = s.substr(ProtocolConstants.BEGIN_CHUNKED_DATA.length);
				idx = ProtocolConstants.BEGIN_CHUNKED_DATA.length;
				buffering = true;
				// Did we get the end chunk too?
				if (s.indexOf(ProtocolConstants.END_CHUNKED_DATA) >= 0) {
					buffer = buffer.substr(buffer.length-ProtocolConstants.END_CHUNKED_DATA.length);
					buffering = false;
				}
			} else if (s.indexOf(ProtocolConstants.END_CHUNKED_DATA) >= 0) {
				buffer += s.substr(idx,s.length-ProtocolConstants.END_CHUNKED_DATA.length);
				buffering = false;
			} else {
				if (buffering) {
					buffer += s;
				}
			}
			if (!buffering){
				if (buffer == null) {
					buffer = s;
				}
				log(buffer);
				buffer = null;
			}
			
		}
		
		
		
		private function sendCrossDomainPolicy():void {
			clientSocket.writeUTF('<cross-domain-policy><allow-access-from domain="*" to-ports="*" /></cross-domain-policy>');
			clientSocket.flush();
		}
	}
}