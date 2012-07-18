package org.bigbluebutton.modules.whiteboard
{
	import flash.display.DisplayObject;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.TextEvent;
	import flash.geom.Point;
	import flash.text.TextFieldAutoSize;
	import flash.ui.Keyboard;
	
	import mx.collections.ArrayCollection;
	
	import org.bigbluebutton.common.IBbbCanvas;
	import org.bigbluebutton.common.LogUtil;
	import org.bigbluebutton.main.events.MadePresenterEvent;
	import org.bigbluebutton.modules.whiteboard.business.shapes.DrawGrid;
	import org.bigbluebutton.modules.whiteboard.business.shapes.DrawObject;
	import org.bigbluebutton.modules.whiteboard.business.shapes.GraphicFactory;
	import org.bigbluebutton.modules.whiteboard.business.shapes.GraphicObject;
	import org.bigbluebutton.modules.whiteboard.business.shapes.ShapeFactory;
	import org.bigbluebutton.modules.whiteboard.business.shapes.TextFactory;
	import org.bigbluebutton.modules.whiteboard.business.shapes.TextObject;
	import org.bigbluebutton.modules.whiteboard.business.shapes.WhiteboardConstants;
	import org.bigbluebutton.modules.whiteboard.events.GraphicObjectFocusEvent;
	import org.bigbluebutton.modules.whiteboard.events.PageEvent;
	import org.bigbluebutton.modules.whiteboard.events.ToggleGridEvent;
	import org.bigbluebutton.modules.whiteboard.events.WhiteboardDrawEvent;
	import org.bigbluebutton.modules.whiteboard.events.WhiteboardSettingResetEvent;
	import org.bigbluebutton.modules.whiteboard.events.WhiteboardUpdate;
	import org.bigbluebutton.modules.whiteboard.views.WhiteboardCanvas;
	
	public class WhiteboardCanvasModel {
		public var wbCanvas:WhiteboardCanvas;
		public var isPresenter:Boolean;		
		
		private var isDrawing:Boolean; 
		private var sending:Boolean = false;
		private var feedback:Shape = new Shape();
		private var latentFeedbacks:Array = new Array();
		private var segment:Array = new Array();
		private var graphicList:Array = new Array();
		
		private var shapeFactory:ShapeFactory = new ShapeFactory();
		private var textFactory:TextFactory = new TextFactory();
		private var bbbCanvas:IBbbCanvas;
		private var lastGraphicObjectSelected:GraphicObject;
		
		private var graphicType:String = WhiteboardConstants.TYPE_SHAPE;
		private var toolType:String = DrawObject.PENCIL;
		private var drawColor:uint = 0x000000;
		private var fillColor:uint = 0x000000;
		private var thickness:uint = 1;
		private var fillOn:Boolean = false;
		private var transparencyOn:Boolean = false;
		
		/* a hack to fix the problem of shapes being cleared on viewers' side when page is changed.
			need to find a better way around later.
		*/
		private var clearOnce:Boolean = true;
		
		/* represents the currently selected TextObject, if any.
		   'selected' in this context means it is currently being edited, or is the most recent
			TextObject to be edited by the presenter
		*/
		private var currentlySelectedTextObject:TextObject;
		
		/* represents the max number of 'points' enumerated in 'segment'
		   before sending an update to server. Used to prevent 
		   spamming red5 with unnecessary packets
		*/
		private var sendShapeFrequency:uint = 30;	
		
		/* same as above, except a faster interval may be desirable
		   when erasing, for aesthetics
		*/
		private var sendEraserFrequency:uint = 20;	
		private var drawStatus:String = DrawObject.DRAW_START;
		private var width:Number;
		private var height:Number;
		
		// isGrid represents the state of the current page (grid vs not grid)
		private var isGrid:Boolean = true;
		// drawGrid is the sprite added to the page when isGrid is true
		private var drawGrid:DrawGrid;
		
		public function doMouseUp():void{
			if(graphicType == WhiteboardConstants.TYPE_SHAPE) {
				if (isDrawing) {
					/**
					 * Check if we are drawing because when resizing the window, it generates
					 * a mouseUp event at the end of resize. We don't want to dispatch another
					 * shape to the viewers.
					 */
					isDrawing = false;
					
					//check to make sure unnecessary data is not sent
					// ex. a single click when the rectangle tool is selected
					// is hardly classifiable as a rectangle, and should not 
					// be sent to the server
					if(toolType == DrawObject.RECTANGLE || 
						toolType == DrawObject.ELLIPSE ||
						toolType == DrawObject.TRIANGLE) {
						
						var x:Number = segment[0];
						var y:Number = segment[1];
						var width:Number = segment[segment.length-2]-x;
						var height:Number = segment[segment.length-1]-y;
						
						if(!(Math.abs(width) <= 2 && Math.abs(height) <=2)) {
							sendShapeToServer(DrawObject.DRAW_END);
						}
					} else {
						sendShapeToServer(DrawObject.DRAW_END);
					}
					
				}
			}
		}
		
		private function sendShapeToServer(status:String):void {
			if (segment.length == 0) return;
			
			var dobj:DrawObject = shapeFactory.createDrawObject(this.toolType, segment, this.drawColor, this.thickness, this.fillOn, this.fillColor, this.transparencyOn);

			switch (status) {
				case DrawObject.DRAW_START:
					dobj.status = DrawObject.DRAW_START;
					drawStatus = DrawObject.DRAW_UPDATE;
					break;
				case DrawObject.DRAW_UPDATE:
					dobj.status = DrawObject.DRAW_UPDATE;								
					break;
				case DrawObject.DRAW_END:
					dobj.status = DrawObject.DRAW_END;
					drawStatus = DrawObject.DRAW_START;
					break;
			}
			
			if (this.toolType == DrawObject.PENCIL ||
				this.toolType == DrawObject.ERASER) {
				dobj.status = DrawObject.DRAW_END;
				drawStatus = DrawObject.DRAW_START;
				segment = new Array();	
				var xy:Array = wbCanvas.getMouseXY();
				segment.push(xy[0], xy[1]);
			}
			
			wbCanvas.sendGraphicToServer(dobj, WhiteboardDrawEvent.SEND_SHAPE);			
		}
		
		private function sendTextToServer(status:String, t:TextObject):void {
			var tobj:TextObject = textFactory.createText(t.text, t.textColor, t.backgroundColor, t.background, t.x, t.y, t.textSize);
			tobj.status = status;	
			tobj.setGraphicID(t.getGraphicID());
			
			wbCanvas.sendGraphicToServer(tobj, WhiteboardDrawEvent.SEND_TEXT);			
		}
		
		public function doMouseDown(mouseX:Number, mouseY:Number):void{
			if(graphicType == WhiteboardConstants.TYPE_SHAPE) {
				isDrawing = true;
				drawStatus = DrawObject.DRAW_START;
				segment = new Array();
				segment.push(mouseX);
				segment.push(mouseY);
			} else if(graphicType == WhiteboardConstants.TYPE_SELECTION) {
				/* The following is some experimental stuff to test out the 
					to-be selection tool.
				*/
				var objs:Array = getGraphicObjectsUnderPoint(mouseX, mouseY);		
				var graphics:Array = filterGraphicObjects(objs)
				var topMostObject:GraphicObject = getTopMostObject(graphics) as GraphicObject;
				
				LogUtil.debug("There are " + graphics.length + " objects" +
					"under your mouse.");
				LogUtil.debug("!!!TOP MOST OBJECT: " + topMostObject.getProperties());
			}
		}
		
		public function doMouseDoubleClick(mouseX:Number, mouseY:Number):void {
			/* creates a new TextObject and sends it to the server to notify all
			   the clients about it
			*/
			if(graphicType == WhiteboardConstants.TYPE_TEXT) {
				LogUtil.error("double click received at " + mouseX + "," + mouseY);
				var tobj:TextObject = new TextObject("TEST", 0x000000, 0x000000, false, mouseX, mouseY, 18);
				sendTextToServer(TextObject.TEXT_CREATED, tobj);
			}
		}
		
		public function doMouseMove(mouseX:Number, mouseY:Number):void{
			if(graphicType == WhiteboardConstants.TYPE_SHAPE) {
				if (isDrawing){
					segment.push(mouseX);
					segment.push(mouseY);
					// added different "send" rates for normal shapes and the eraser
					// in case one is preferable to the other
					if(toolType == DrawObject.ERASER) {
						if (segment.length > sendEraserFrequency) {
							sendShapeToServer(drawStatus);
						}
					} else {
						if (segment.length > sendShapeFrequency) {
							sendShapeToServer(drawStatus);
						}
					}	
				}
			}
		}
		
		public function drawGraphic(event:WhiteboardUpdate):void{
			var o:GraphicObject = event.data;
			var recvdShapes:Boolean = event.recvdShapes;
			
			if(o.getGraphicType() == WhiteboardConstants.TYPE_SHAPE) {
				var dobj:DrawObject = o as DrawObject;
				drawShape(dobj, recvdShapes);	
				
			} else if(o.getGraphicType() == WhiteboardConstants.TYPE_TEXT) { 
				var tobj:TextObject = o as TextObject;
				drawText(tobj, recvdShapes);	
			}
		}
		
		// Draws a DrawObject when/if it is received from the server
		private function drawShape(o:DrawObject, recvdShapes:Boolean):void {	
			switch (o.status) {
				case DrawObject.DRAW_START:
					addNewShape(o);														
					break;
				case DrawObject.DRAW_UPDATE:
				case DrawObject.DRAW_END:
					if (graphicList.length == 0 || 
						o.getType() == DrawObject.PENCIL ||
						o.getType() == DrawObject.ERASER ||
						recvdShapes) {
						addNewShape(o);
					} else {
						removeLastGraphic();		
						addNewShape(o);
					}					
					break;
			}        
		}
		
		// Draws a TextObject when/if it is received from the server
		private function drawText(o:TextObject, recvdShapes:Boolean):void {		
			if(recvdShapes) {
				LogUtil.debug("Got text [" + o.text + " " + 
					o.status + " " + o.getGraphicID() + "]");	
				LogUtil.debug(String(o.getProperties()));
			}
			switch (o.status) {
				case TextObject.TEXT_CREATED:
					if(isPresenter)
						addPresenterText(o);
					else
						addViewerText(o);														
					break;
				case TextObject.TEXT_UPDATED:
				case TextObject.TEXT_PUBLISHED:
					if(isPresenter) {
						if(recvdShapes) addPresenterText(o);
					} else {
						if(graphicList.length == 0 || recvdShapes) {
							addViewerText(o);
						} else modifyText(o);
					} 	
					break;
			}        
		}
		
		private function addNewShape(o:DrawObject):void {
			var dobj:DrawObject = shapeFactory.makeShape(o);
			wbCanvas.addGraphic(dobj);
			graphicList.push(dobj);
		}
		
		private function calibrateTextWith(o:TextObject):TextObject {
			var tobj:TextObject;
			tobj = textFactory.makeText(o);
			tobj.setGraphicID(o.getGraphicID());
			tobj.status = o.status;
			tobj.applyFormatting();
			return tobj;
		}
			
		/* adds a new TextObject that is suited for a presenter. For example, it will
		   be made editable and the appropriate listeners will be registered so that
		   the required events will be dispatched 
		*/
		private function addPresenterText(o:TextObject):void {
			if(!isPresenter) return;
			LogUtil.debug("Created text: " + o.getGraphicID());
			var tobj:TextObject = calibrateTextWith(o);
			tobj.makeEditable(true);
			tobj.registerListeners(tobjGainFocusListener,
									tobjLoseFocusListener,
									tobjTextListener,
									textObjSpecialListener);
			wbCanvas.addGraphic(tobj);
			wbCanvas.stage.focus = tobj;
			graphicList.push(tobj);
		}
		
		/* adds a new TextObject that is suited for a viewer. For example, it will not
		   be made editable and no listeners need to be attached because the viewers
		   should not be able to edit/modify the TextObject 
		*/
		private function addViewerText(o:TextObject):void {
			if(isPresenter) return;
			var tobj:TextObject = calibrateTextWith(o);
			tobj.makeEditable(false);
			wbCanvas.addGraphic(tobj);
			graphicList.push(tobj);
		}
		
		/* method to modify a TextObject that is already present on the whiteboard,
			as opposed to adding a new TextObject to the whiteboard
		*/
		private function modifyText(o:TextObject):void {
			var tobj:TextObject = calibrateTextWith(o);
			var id:String = tobj.getGraphicID();
			removeText(id);
			LogUtil.debug("Text modified to " + tobj.text);
			addViewerText(tobj);
		}
		
		/* invoked by the WhiteboardManager that is invoked by the TextToolbar, that 
		   specifies the currently selected TextObject to change its attributes. For example,
		   when a 'text color' ColorPicker is changed in the TextToolbar, the invocation
		   eventually reaches this method that causes the currently selected TextObject
		   to be re-sent to the red5 server with the modified attributes.
		*/
		public function modifySelectedTextObject(textColor:uint, bgColorVisible:Boolean, backgroundColor:uint, textSize:Number):void {
			currentlySelectedTextObject.textColor = textColor;
			currentlySelectedTextObject.background = bgColorVisible;
			currentlySelectedTextObject.backgroundColor = backgroundColor;
			currentlySelectedTextObject.textSize = textSize;
			currentlySelectedTextObject.applyFormatting();
			sendTextToServer(TextObject.TEXT_PUBLISHED, currentlySelectedTextObject);
		}
		
		public function setGraphicType(type:String):void{
			this.graphicType = type;
		}
		
		public function setTool(s:String):void{
			this.toolType = s;
		}
		
		public function changeColor(color:uint):void{
			drawColor = color;
		}
		
		public function changeFillColor(color:uint):void{
			fillColor = color;
		}
			
		public function changeThickness(thickness:uint):void{
			this.thickness = thickness;
		}
		
		public function toggleFill():void{
			fillOn = !fillOn;
		}
		
		public function toggleTransparency():void{
			transparencyOn = !transparencyOn;
		}
		
		/* sets the fill mode boolean to the specified value
		Used when one wants to set it to a specific value. 
		*/
		public function setFill(fill:Boolean):void{
			this.fillOn = fill;
		}
		
		/* sets the transparent mode boolean to the specified value
			Used when one wants to set it to a specific value. 
		*/
		public function setTransparent(transp:Boolean):void{
			this.transparencyOn = transp;
		}

		/* the following three methods are used to remove any GraphicObjects (and its
			subclasses) if the id of the object to remove is specified. The latter
			two are convenience methods, the main one is the first of the three.
		*/
		private function removeGraphic(id:String):void {
			var gobjData:Array = getGobjInfoWithID(id);
			var removeIndex:int = gobjData[0];
			var gobjToRemove:GraphicObject = gobjData[1] as GraphicObject;
			wbCanvas.removeGraphic(gobjToRemove as DisplayObject);
			graphicList.splice(removeIndex, 1);
		}	
	
		private function removeShape(id:String):void {
			var dobjData:Array = getGobjInfoWithID(id);
			var removeIndex:int = dobjData[0];
			var dobjToRemove:DrawObject = dobjData[1] as DrawObject;
			wbCanvas.removeGraphic(dobjToRemove);
			graphicList.splice(removeIndex, 1);
		}
	
		private function removeText(id:String):void {
			var tobjData:Array = getGobjInfoWithID(id);
			var removeIndex:int = tobjData[0];
			var tobjToRemove:TextObject = tobjData[1] as TextObject;
			wbCanvas.removeGraphic(tobjToRemove);
			graphicList.splice(removeIndex, 1);
		}	
		
		/* returns an array of the GraphicObject that has the specified id,
		 and the index of that GraphicObject (if it exists, of course) 
		*/
		private function getGobjInfoWithID(id:String):Array {	
			var data:Array = new Array();
			for(var i:int = 0; i < graphicList.length; i++) {
				var currObj:GraphicObject = graphicList[i] as GraphicObject;
				if(currObj.getGraphicID() == id) {
					data.push(i);
					data.push(currObj);
					return data;
				}
			}
			return null;
		}

		private function removeLastGraphic():void {
			var gobj:GraphicObject = graphicList.pop();
			if(gobj.getGraphicType() == WhiteboardConstants.TYPE_TEXT) {
				(gobj as TextObject).makeEditable(false);
				(gobj as TextObject).deregisterListeners(tobjGainFocusListener,
					tobjLoseFocusListener,
					tobjTextListener,
					textObjSpecialListener);
			}	
			wbCanvas.removeGraphic(gobj as DisplayObject);
		}

		// returns all DrawObjects in graphicList
		private function getAllShapes():Array {
			var shapes:Array = new Array();
			for(var i:int = 0; i < graphicList.length; i++) {
				var currGobj:GraphicObject = graphicList[i];
				if(currGobj.getGraphicType() == WhiteboardConstants.TYPE_SHAPE) {
					shapes.push(currGobj as DrawObject);
				}
			}
			return shapes;
		}
		
		// returns all TextObjects in graphicList
		private function getAllTexts():Array {
			var texts:Array = new Array();
			for(var i:int = 0; i < graphicList.length; i++) {
				var currGobj:GraphicObject = graphicList[i];
				if(currGobj.getGraphicType() == WhiteboardConstants.TYPE_TEXT) {
					texts.push(currGobj as TextObject)
				}
			}
			return texts;
		}
		
		public function clearBoard(event:WhiteboardUpdate = null):void {
			var numGraphics:int = this.graphicList.length;
			for (var i:Number = 0; i < numGraphics; i++){
				removeLastGraphic();
			}
		}
		
		public function undoGraphic():void{
			if (this.graphicList.length > 0) {
				removeLastGraphic();
			}
		}

		public function changePage(e:PageEvent):void{
			var page:Number = e.pageNum;
			var graphicObjs:ArrayCollection = e.graphicObjs;
			this.isGrid = e.isGrid;
			
			LogUtil.debug("CHANGING PAGE");
			clearBoard();
			for (var i:int = 0; i < graphicObjs.length; i++){
				var o:GraphicObject = graphicObjs.getItemAt(i) as GraphicObject;
				if(o.getGraphicType() == WhiteboardConstants.TYPE_SHAPE)
					drawShape(o as DrawObject, true);
				else if(o.getGraphicType() == WhiteboardConstants.TYPE_TEXT) 
					drawText(o as TextObject, true);	
			}
			
			if(isPresenter) {
				var evt:GraphicObjectFocusEvent = 
					new GraphicObjectFocusEvent(GraphicObjectFocusEvent.OBJECT_DESELECTED);
				evt.data = null;
				wbCanvas.dispatchEvent(evt);
			}
			// if the new page has a grid, draw it
			addOrRemoveGrid(this.isGrid);

			LogUtil.debug("GRAPHIC LIST SIZE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " + graphicList.length);
		}
		
		public function zoomCanvas(width:Number, height:Number):void{
			shapeFactory.setParentDim(width, height);	
			textFactory.setParentDim(width, height);
			this.width = width;
			this.height = height;

			for (var i:int = 0; i < this.graphicList.length; i++){
				redrawGraphic(this.graphicList[i] as GraphicObject, i);
			}		
			// if the grid was drawn, redraw it with the new width and height
			if(isGrid) {
				addOrRemoveGrid(true, width, height);
			}
		}
		
		// toggles the gridmode on or off
		public function toggleGrid(event:ToggleGridEvent = null):void{
			isGrid = !isGrid;
			LogUtil.debug("Final gridToggle received " + isGrid + " " + wbCanvas.width + "," + wbCanvas.height);
			addOrRemoveGrid(isGrid, wbCanvas.width, wbCanvas.height);
			var gridChangedEvent:WhiteboardSettingResetEvent = 
				new WhiteboardSettingResetEvent(WhiteboardSettingResetEvent.GRID_CHANGED);
			gridChangedEvent.value = isGrid;
			wbCanvas.dispatchEvent(gridChangedEvent);
		}
		
		/* adds or removes the grid based on the the different parameters passed.
			Also used to redraw the grid when canvas is zoomed/moved
		*/
		private function addOrRemoveGrid(grid:Boolean, width:Number = 0, height:Number = 0):void {	
			if(width == 0) width = wbCanvas.width;
			if(height == 0) height = wbCanvas.height;
			if(drawGrid == null)
				drawGrid = new DrawGrid(width,height,10,10);
			if(!wbCanvas.doesContain(drawGrid) && grid) wbCanvas.addGraphic(drawGrid);
			LogUtil.debug("Grid added");
			if(grid) {
				drawGrid.setSize(width, height);
			} else {
				wbCanvas.removeGraphic(drawGrid);
			}
		}
		
		/* called when a user is made presenter, automatically make all the textfields
		   currently on the page editable, so that they can edit it.
		*/
		public function makeTextObjectsEditable(e:MadePresenterEvent):void {
			isPresenter = true;
			var texts:Array = getAllTexts();
			for(var i:int = 0; i < texts.length; i++) {
				(texts[i] as TextObject).makeEditable(true);
				(texts[i] as TextObject).registerListeners(tobjGainFocusListener,
					tobjLoseFocusListener,
					tobjTextListener,
					textObjSpecialListener);
			}
		}
		
		/* when a user is made viewer, automatically make all the textfields
		   currently on the page uneditable, so that they cannot edit it any
		   further and so that only the presenter can edit it.
		*/
		public function makeTextObjectsUneditable(e:MadePresenterEvent):void {
			LogUtil.debug("MADE PRESENTER IS PRESENTER FALSE");
			isPresenter = false;
			var texts:Array = getAllTexts();
			for(var i:int = 0; i < texts.length; i++) {
				(texts[i] as TextObject).makeEditable(false);
				(texts[i] as TextObject).deregisterListeners(tobjGainFocusListener,
					tobjLoseFocusListener,
					tobjTextListener,
					textObjSpecialListener);

			}
		}

		/* the following four methods  are listeners that handle events that occur
			on TextObjects, such as text being typed, which causes the textObjTextListener
			to send text to the server.
		*/
		public function textObjSpecialListener(event:KeyboardEvent):void {
			// check for special conditions
			if(event.charCode == 127 || // 'delete' key
				event.charCode == 8 || // 'bkspace' key
				event.charCode == 13) { // 'enter' key
				var sendStatus:String = TextObject.TEXT_UPDATED;
				var tobj:TextObject = event.target as TextObject;	
				
				// if the enter key is pressed, remove focus from the 
				// TextObject so that it is sent to the server.
				if(event.charCode == 13) {
					wbCanvas.stage.focus = null;
					tobj.stage.focus = null;
					return;
				}
				sendTextToServer(sendStatus, tobj);	
			} 	
			
		}
		
		public function tobjTextListener(event:TextEvent):void {
			var sendStatus:String = TextObject.TEXT_UPDATED;
			var tf:TextObject = event.target as TextObject;	
			LogUtil.debug("ID " + tf.getGraphicID() + " modified to "+ tf.text);
			sendTextToServer(sendStatus, tf);	
		}
		
		public function tobjGainFocusListener(event:FocusEvent):void {
			var tf:TextObject = event.currentTarget as TextObject;
			wbCanvas.stage.focus = tf;
			tf.stage.focus = tf;
			currentlySelectedTextObject = tf;
			var e:GraphicObjectFocusEvent = new GraphicObjectFocusEvent(GraphicObjectFocusEvent.OBJECT_SELECTED);
			e.data = tf;
			wbCanvas.dispatchEvent(e);
		}
		
		public function tobjLoseFocusListener(event:FocusEvent):void {
			var tf:TextObject = event.target as TextObject;	
			sendTextToServer(TextObject.TEXT_PUBLISHED, tf);	
			LogUtil.debug("Text published to: " +  tf.text);
			
			/* hide text toolbar because we don't want to show it
				if there is no text selected */
			var e:GraphicObjectFocusEvent = new GraphicObjectFocusEvent(GraphicObjectFocusEvent.OBJECT_DESELECTED);
			e.data = tf;
			wbCanvas.dispatchEvent(e);
			
		}
		
		private function redrawGraphic(gobj:GraphicObject, objIndex:int):void {
			if(gobj.getGraphicType() == WhiteboardConstants.TYPE_SHAPE) {
				var origDobj:DrawObject = gobj as DrawObject;
				wbCanvas.removeGraphic(origDobj);
				origDobj.graphics.clear();
				var dobj:DrawObject =  shapeFactory.makeShape(origDobj);
				dobj.setGraphicID(origDobj.getGraphicID());
				dobj.status = origDobj.status;
				wbCanvas.addGraphic(dobj);
				graphicList[objIndex] = dobj;	
			} else if(gobj.getGraphicType() == WhiteboardConstants.TYPE_TEXT) {
				// haven't thought of rescaling of the text, will do later
			}
		}
		
		public function isPageEmpty():Boolean {
			return graphicList.length == 0;
		}
		
		/* The next three methods are used for the "selection tool" that I haven't finished implementing yet.
		   The idea of the selection tool is to be able to figure out what is the top most object and distinguish
			the object from those that may be beneath it. The idea is to allow for the user to select individual
			GraphicObjects (maybe a shape or even a text box), and allow for modification of individual elements
			For example, a user could click on a rectangle shape that would then appear to become "selected", so that the user
			could take actions on the shape such as rotate, delete, resize, etc. These are just the plans, and have not been 
			implemented yet, so the selection tool does not really have a purpose currently.
		*/
		private function getGraphicObjectsUnderPoint(xf:Number, yf:Number):Array {
			// below is a nasty hack to get normalized/denormalized coordinates of 
			// "normal" coordinates. will change later.
			/*var x:Number = 
				GraphicFactory.denormalize(
					GraphicFactory.normalize(xf,
						textFactory.getParentWidth()), textFactory.getParentWidth());
			var y:Number = 
				GraphicFactory.denormalize(
					GraphicFactory.normalize(yf,
					textFactory.getParentHeight()), textFactory.getParentHeight());
			var point:Point = new Point(x,y);
			point = wbCanvas.localToGlobal(point);
			
			return wbCanvas.parentApplication.getObjectsUnderPoint(point);*/
			return null;
		}
		
		private function filterGraphicObjects(objs:Array):Array {
			return objs.filter(
				function callback(item:*, index:int, array:Array):Boolean
				{
					return item is GraphicObject;
				}
			);
		}
		
		private function getTopMostObject(objs:Array):Object {
			var topMostObj:Object;

			for(var i:int = objs.length-2; i >= 0; i--) {
				var firstIndex:int = 
					wbCanvas.parentApplication.getChildIndex(objs[i]);
				var secondIndex:int = 
					wbCanvas.parentApplication.getChildIndex(objs[i+1]);
				topMostObj = 
					(firstIndex > secondIndex) ? firstIndex : secondIndex;
			}
			
			return topMostObj;
		}


	}
}
