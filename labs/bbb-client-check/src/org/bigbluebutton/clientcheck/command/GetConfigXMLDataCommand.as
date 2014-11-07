package org.bigbluebutton.clientcheck.command
{
	import flash.net.URLRequest;

	import mx.core.FlexGlobals;
	import mx.utils.URLUtil;

	import org.bigbluebutton.clientcheck.model.ISystemConfiguration;
	import org.bigbluebutton.clientcheck.model.IXMLConfig;
	import org.bigbluebutton.clientcheck.model.test.IPortTest;
	import org.bigbluebutton.clientcheck.model.test.IRTMPAppTest;
	import org.bigbluebutton.clientcheck.model.test.PortTest;
	import org.bigbluebutton.clientcheck.model.test.RTMPAppTest;
	import org.bigbluebutton.clientcheck.service.ConfigService;

	import robotlegs.bender.bundles.mvcs.Command;

	public class GetConfigXMLDataCommand extends Command
	{
		[Inject]
		public var systemConfiguration:ISystemConfiguration;

		[Inject]
		public var config:IXMLConfig;

		private var CONFIG_XML:String="client/client-check/conf/config.xml";
		private var _urlRequest:URLRequest;

		public override function execute():void
		{
			var configSubservice:ConfigService=new ConfigService();

			configSubservice.successSignal.add(afterConfig);
			configSubservice.unsuccessSignal.add(fail);
			configSubservice.getConfig(buildRequestURL(), _urlRequest);
		}

		private function buildRequestURL():String
		{
			var swfPath:String=FlexGlobals.topLevelApplication.url;
			var protocol:String=URLUtil.getProtocol(swfPath);
			systemConfiguration.serverName=URLUtil.getServerNameWithPort(swfPath);

			return protocol + "://" + systemConfiguration.serverName + "/" + CONFIG_XML;
		}

		private function fail(reason:String):void
		{
			// TODO: create pop up to notify about failure
		}

		private function afterConfig(data:Object):void
		{
			config.init(new XML(data));
			systemConfiguration.downloadFilePath=config.downloadFilePath.url;
			systemConfiguration.applicationAddress=config.serverUrl.url;

			for each (var _port:Object in config.getPorts())
			{
				var port:IPortTest=new PortTest();
				port.portName=_port.name;
				port.portNumber=_port.number;
				systemConfiguration.ports.push(port);
			}

			for each (var _rtmpApp:Object in config.getRTMPApps())
			{
				var app:IRTMPAppTest=new RTMPAppTest();
				app.applicationName=_rtmpApp.name;
				app.applicationUri=_rtmpApp.uri;
				systemConfiguration.rtmpApps.push(app);
			}

			config.configParsedSignal.dispatch();
		}
	}
}
