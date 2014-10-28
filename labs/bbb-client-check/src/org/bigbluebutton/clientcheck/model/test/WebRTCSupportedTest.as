package org.bigbluebutton.clientcheck.model.test
{
	import org.osflash.signals.ISignal;
	import org.osflash.signals.Signal;

	public class WebRTCSupportedTest implements ITestable
	{
		public static var WEBRTC_SUPPORTED:String="WebRTC Supported";

		private var _testSuccessfull:Boolean;
		private var _testResult:String;

		private var _webRTCSupportedTestSuccessfullChangedSignal:ISignal=new Signal;

		public function get testSuccessfull():Boolean
		{
			return _testSuccessfull;
		}

		public function set testSuccessfull(value:Boolean):void
		{
			_testSuccessfull=value;
			webRTCSupportedTestSuccessfullChangedSignal.dispatch();
		}

		public function get testResult():String
		{
			return _testResult;
		}

		public function set testResult(value:String):void
		{
			_testResult=value;
		}

		public function get webRTCSupportedTestSuccessfullChangedSignal():ISignal
		{
			return _webRTCSupportedTestSuccessfullChangedSignal;
		}
	}
}
