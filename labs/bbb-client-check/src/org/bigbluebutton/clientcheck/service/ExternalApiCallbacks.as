package org.bigbluebutton.clientcheck.service
{
	import flash.external.ExternalInterface;

	import org.bigbluebutton.clientcheck.model.ISystemConfiguration;
	import org.bigbluebutton.clientcheck.model.test.ITestable;

	public class ExternalApiCallbacks implements IExternalApiCallbacks
	{
		[Inject]
		public var systemConfiguration:ISystemConfiguration;

		private static var UNDEFINED:String="Undefined";

		public function ExternalApiCallbacks()
		{
			if (ExternalInterface.available)
			{
				ExternalInterface.addCallback("userAgent", userAgentCallbackHandler);
				ExternalInterface.addCallback("browser", browserCallbackHandler);
				ExternalInterface.addCallback("screenSize", screenSizeCallbackHandler);
				ExternalInterface.addCallback("isPepperFlash", isPepperFlashCallbackHandler);
				ExternalInterface.addCallback("cookieEnabled", cookieEnabledCallbackHandler);
				ExternalInterface.addCallback("javaEnabled", javaEnabledCallbackHandler);
				ExternalInterface.addCallback("language", languageCallbackHandler);
				ExternalInterface.addCallback("isWebRTCSupported", isWebRTCSupportedCallbackHandler);
				ExternalInterface.addCallback("webRTCEchoTest", webRTCEchoTestCallbackHandler);
				ExternalInterface.addCallback("webRTCSocketTest", webRTCSocketTestCallbackHandler);
			}
		}

		private function checkResult(result:String, item:ITestable):void
		{
			if ((result == null) || (result == ""))
			{
				item.testResult=UNDEFINED;
				item.testSuccessfull=false;
			}
			else
			{
				item.testResult=result;
				item.testSuccessfull=true
			}
		}

		public function webRTCSocketTestCallbackHandler(success:Boolean, result:String):void
		{
			systemConfiguration.webRTCSocketTest.testResult=result;
			systemConfiguration.webRTCSocketTest.testSuccessfull=success;
		}

		public function webRTCEchoTestCallbackHandler(success:Boolean, result:String):void
		{
			systemConfiguration.webRTCEchoTest.testResult=result;
			systemConfiguration.webRTCEchoTest.testSuccessfull=success;
		}

		public function isPepperFlashCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.isPepperFlash);
		}

		public function languageCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.language);
		}

		public function javaEnabledCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.javaEnabled);
		}

		public function isWebRTCSupportedCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.isWebRTCSupported);
		}

		public function cookieEnabledCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.cookieEnabled);
		}

		public function screenSizeCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.screenSize);
		}

		private function browserCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.browser);
		}

		public function userAgentCallbackHandler(value:String):void
		{
			checkResult(value, systemConfiguration.userAgent);
		}
	}
}
