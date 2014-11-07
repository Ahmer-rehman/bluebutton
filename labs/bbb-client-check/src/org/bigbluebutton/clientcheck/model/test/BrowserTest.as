package org.bigbluebutton.clientcheck.model.test
{
	import org.osflash.signals.ISignal;
	import org.osflash.signals.Signal;

	public class BrowserTest implements ITestable
	{
		public static var BROWSER:String="Browser";

		private var _testSuccessfull:Boolean;
		private var _testResult:String;

		private var _browserTestSuccessfullChangedSignal:ISignal=new Signal;

		public function get testSuccessfull():Boolean
		{
			return _testSuccessfull;
		}

		public function set testSuccessfull(value:Boolean):void
		{
			_testSuccessfull=value;
			_browserTestSuccessfullChangedSignal.dispatch();
		}

		public function get testResult():String
		{
			return _testResult;
		}

		public function set testResult(value:String):void
		{
			_testResult=value;
		}

		public function get browserTestSuccessfullChangedSignal():ISignal
		{
			return _browserTestSuccessfullChangedSignal;
		}
	}
}
