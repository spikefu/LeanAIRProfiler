package com.yellowbadger.profiler.server.impl
{
	import com.yellowbadger.profiler.server.IProfilerSettings;

	public class ProfilerSettings implements IProfilerSettings
	{
		private var _autoStart:Boolean;
		
		public function set autoStart(value:Boolean):void {
			_autoStart = value;
		}
		
		public function get autoStart():Boolean {
			return _autoStart;
		}
	}
}