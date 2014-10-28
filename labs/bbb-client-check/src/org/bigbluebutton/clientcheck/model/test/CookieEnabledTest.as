package org.bigbluebutton.clientcheck.model.test
{
	import org.osflash.signals.ISignal;
	import org.osflash.signals.Signal;

	public class CookieEnabledTest implements ITestable
	{
		public static var COOKIE_ENABLED:String="Cookie enabled";

		private var _testSuccessfull:Boolean;
		private var _testResult:String;

		private var _cookieEnabledTestSuccessfullChangedSignal:ISignal=new Signal;

		public function get testSuccessfull():Boolean
		{
			return _testSuccessfull;
		}

		public function set testSuccessfull(value:Boolean):void
		{
			_testSuccessfull=value;
			cookieEnabledTestSuccessfullChangedSignal.dispatch();
		}

		public function get testResult():String
		{
			return _testResult;
		}

		public function set testResult(value:String):void
		{
			_testResult=value;
		}

		public function get cookieEnabledTestSuccessfullChangedSignal():ISignal
		{
			return _cookieEnabledTestSuccessfullChangedSignal;
		}
	}
}
