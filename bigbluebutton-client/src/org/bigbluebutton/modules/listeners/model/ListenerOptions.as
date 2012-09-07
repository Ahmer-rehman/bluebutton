package org.bigbluebutton.modules.listeners.model
{
	import org.bigbluebutton.core.BBB;

	public class ListenerOptions
	{
		[Bindable]
		public var windowVisible:Boolean = true;
		
		[Bindable]
		public var position:String = "bottom-left";
		
		[Bindable]
		public var pushToTalk:Boolean = false;
		
		public function ListenerOptions()
		{
			var vxml:XML = BBB.getConfigForModule("ListenersModule");
			if (vxml != null) {
				windowVisible = (vxml.@windowVisible.toString().toUpperCase() == "TRUE") ? true : false;
			}
			if (vxml.@position != undefined) {
				position = vxml.@position.toString();
			}
			if (vxml.@pushToTalk != undefined) {
				pushToTalk = (vxml.@pushToTalk.toString().toUpperCase() == "TRUE") ? true : false;
			}
		}

	}
}