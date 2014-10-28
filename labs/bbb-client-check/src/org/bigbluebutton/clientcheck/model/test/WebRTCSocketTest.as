package org.bigbluebutton.clientcheck.model.test
{
	import org.osflash.signals.ISignal;
	import org.osflash.signals.Signal;

	public class WebRTCSocketTest implements ITestable
	{
		public static var WEBRTC_SOCKET_TEST:String="WebRTC Socket Test";

		private var _testSuccessfull:Boolean;
		private var _testResult:String;

		private var _webRTCSocketTestSuccessfullChangedSignal:ISignal=new Signal;

		public function get testSuccessfull():Boolean
		{
			return _testSuccessfull;
		}

		public function set testSuccessfull(value:Boolean):void
		{
			_testSuccessfull=value;
			webRTCSocketTestSuccessfullChangedSignal.dispatch();
		}

		public function get testResult():String
		{
			return _testResult;
		}

		public function set testResult(value:String):void
		{
			_testResult=value;
		}

		public function get webRTCSocketTestSuccessfullChangedSignal():ISignal
		{
			return _webRTCSocketTestSuccessfullChangedSignal;
		}
	}
}
