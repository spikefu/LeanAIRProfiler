package com.yellowbadger.profiler.util
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	public class MMCfgUtil
	{
		public static function writePreloaderConfig(preloaderPath:String):void {
			var f:File = File.userDirectory;
			var cfgFile:File = f.resolvePath("mm.cfg"); 
			
			var fs:FileStream = new FileStream();
			var ba:ByteArray = new ByteArray();
			if (cfgFile.exists) {
				fs.open(cfgFile,FileMode.READ);
				if (fs.bytesAvailable > 0) {
					fs.readBytes(ba,0,fs.bytesAvailable);
					var contents:String = ba.toString();
					if (contents.indexOf("PreloadSWF="+preloaderPath) >= 0) {
						fs.close();
						return;
					}
				}
				fs.close();
			}
			fs.open(cfgFile,FileMode.APPEND);
			var s:String = "PreloadSWF="+preloaderPath;
			ba = new ByteArray();
			ba.writeUTFBytes(s);
			fs.writeBytes(ba);
			fs.close();
		}
		
		public static function clearPreloaderConfig(preloaderPath:String):void {
			var f:File = File.userDirectory;
			var cfgFile:File = f.resolvePath("mm.cfg"); 
			if (!cfgFile.exists) {
				return;
			}
			var token:String = "PreloadSWF="+preloaderPath + File.lineEnding;
			var fs:FileStream = new FileStream();
			var contents:String;
			var ba:ByteArray = new ByteArray();
			if (cfgFile.exists) {
				fs.open(cfgFile,FileMode.READ);
				if (fs.bytesAvailable > 0) {
					fs.readBytes(ba,0,fs.bytesAvailable);
					contents = ba.toString();
					if (contents.indexOf(token) < 0) {
						fs.close();
						return;
					}
					fs.close();
					while (contents.indexOf(token) >=0) {
						contents = contents.substr(0,contents.indexOf(token)) + contents.substring(contents.indexOf(token)+token.length);
					}
					fs.open(cfgFile,FileMode.WRITE);
					ba = new ByteArray();
					ba.writeUTFBytes(contents);
					fs.writeBytes(ba);
					fs.close();
				}
			}
		}
	}
}