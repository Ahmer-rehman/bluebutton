package org.bigbluebutton.modules.present.services
{
    import flash.events.AsyncErrorEvent;
    import flash.events.IEventDispatcher;
    import flash.events.NetStatusEvent;
    import flash.events.SyncEvent;
    import flash.net.Responder;
    import flash.net.SharedObject;
    
    import org.bigbluebutton.common.LogUtil;
    import org.bigbluebutton.core.model.MeetingModel;
    import org.bigbluebutton.core.services.Red5BBBAppConnectionService;
    import org.bigbluebutton.main.events.BBBEvent;
    import org.bigbluebutton.main.events.MadePresenterEvent;
    import org.bigbluebutton.modules.present.events.CursorEvent;
    import org.bigbluebutton.modules.present.events.MoveEvent;
    import org.bigbluebutton.modules.present.events.NavigationEvent;
    import org.bigbluebutton.modules.present.events.RemovePresentationEvent;
    import org.bigbluebutton.modules.present.events.UploadEvent;
    import org.bigbluebutton.modules.present.events.ZoomEvent;
    import org.bigbluebutton.modules.present.models.PresentationModel;
    import org.bigbluebutton.modules.present.vo.InitialPresentation;

    public class PresentationSOService
    {        
        private static const SHAREDOBJECT:String = "presentationSO";
        private static const PRESENTER:String = "presenter";
        private static const SHARING:String = "sharing";
        private static const UPDATE_MESSAGE:String = "updateMessage";
        private static const CURRENT_PAGE:String = "currentPage";
                
        public var red5Conn:Red5BBBAppConnectionService;
        public var meetingModel:MeetingModel;
        public var presentationModel:PresentationModel;
        
        private var url:String;
        private var userid:Number;
        
        private var _presentationSO:SharedObject;
        private var _dispatcher:IEventDispatcher;
        private var _connectionListener:Function;
        private var _messageSender:Function;
        private var _soErrors:Array;
                
        public function PresentationSOService(dispatcher:IEventDispatcher){
            _dispatcher = dispatcher;
        }
        
        public function connect():void {
            _presentationSO = SharedObject.getRemote(SHAREDOBJECT, red5Conn.connectionUri, false);	
            _presentationSO.client = this;
            _presentationSO.addEventListener(SyncEvent.SYNC, syncHandler);
            _presentationSO.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
            _presentationSO.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);					
            _presentationSO.connect(red5Conn.connection);
        }
        
        public function disconnect():void {
            if (_presentationSO != null) _presentationSO.close();
        }
        
              
        /**
         * Send an event to the server to update the presenter's cursor view on the client 
         * @param xPercent
         * @param yPercent
         * 
         */		
        public function sendCursorUpdate(xPercent:Number, yPercent:Number):void {
            _presentationSO.send("updateCursorCallback", xPercent, yPercent);
        }
        
        /**
         * A callback method for the cursor update. Called whenever the presenter moves the mouse within the present window
         * @param xPercent
         * @param yPercent
         * 
         */		
        public function updateCursorCallback(xPercent:Number, yPercent:Number):void {
            var e:CursorEvent = new CursorEvent(CursorEvent.UPDATE_CURSOR);
            e.xPercent = xPercent;
            e.yPercent = yPercent;
            _dispatcher.dispatchEvent(e);
        }
        
       
        /**
         * Sends an event to the server to update the clients with the new slide position 
         * @param slideXPosition
         * @param slideYPosition
         * 
         */		
        public function move(xOffset:Number, yOffset:Number, widthRatio:Number, heightRatio:Number):void{
            red5Conn.connection.call("presentation.resizeAndMoveSlide",// Remote function name
                new Responder(
                    function(result:Boolean):void {                         
                        if (result) {
                            LogUtil.debug("Successfully sent resizeAndMoveSlide");							
                        }	
                    },	
                    function(status:Object):void { 
                        LogUtil.error("Error occurred:"); 
                        for (var x:Object in status) { 
                            LogUtil.error(x + " : " + status[x]); 
                        } 
                    }
                ), //new Responder
                xOffset,
                yOffset,
                widthRatio,
                heightRatio
            ); //_netConnection.call
        }
        
        /**
         * A callback method from the server to update the slide position 
         * @param slideXPosition
         * @param slideYPosition
         * 
         */		
        public function moveCallback(xOffset:Number, yOffset:Number, widthRatio:Number, heightRatio:Number):void{
            var e:MoveEvent = new MoveEvent(MoveEvent.MOVE);
            e.xOffset = xOffset;
            e.yOffset = yOffset;
            e.slideToCanvasWidthRatio = widthRatio;
            e.slideToCanvasHeightRatio = heightRatio;
            _dispatcher.dispatchEvent(e);
        }
        

        
        public function removePresentation(name:String):void {
            red5Conn.connection.call("presentation.removePresentation",// Remote function name
                new Responder(
                    function(result:Boolean):void { 						 
                        if (result) {
                            LogUtil.debug("Successfully assigned presenter to: " + userid);							
                        }	
                    },	
                    // status - On error occurred
                    function(status:Object):void { 
                        LogUtil.error("Error occurred:"); 
                        for (var x:Object in status) { 
                            LogUtil.error(x + " : " + status[x]); 
                        } 
                    }
                ), //new Responder
                name
            ); //_netConnection.call
        }
               
        public function getPresentationInfo():void {
            red5Conn.connection.call("presentation.getPresentationInfo",// Remote function name
                new Responder(
                    function(result:Object):void { 	
                        LogUtil.debug("Successfully querried for presentation information.");	
                        var ip:InitialPresentation = new InitialPresentation();
                        ip.hasPresenter = result.presenter.hasPresenter;
                        ip.xOffset = Number(result.presentation.xOffset);
                        ip.yOffset = Number(result.presentation.yOffset);
                        ip.widthRatio = Number(result.presentation.widthRatio);
                        ip.heightRatio = Number(result.presentation.heightRatio);
                        
                        if (result.presentations) {
                            for(var p:Object in result.presentations) {
                                var u:Object = result.presentations[p]
                                LogUtil.debug("Presentation name " + u as String);
                                ip.presentations.addItem(u as String);
                            }
                        }
                                              
                        if (result.presentation.sharing) {	
                            ip.sharing = result.presentation.sharing;
                            ip.currentPage = Number(result.presentation.slide);
                            LogUtil.debug("The presenter has shared slides and showing slide " + ip.currentPage);
                            ip.presentationName = String(result.presentation.currentPresentation);
                        }
                        
                        presentationModel.setInitialPresentation(ip);
                    },	
                    // status - On error occurred
                    function(status:Object):void { 
                        LogUtil.error("Error occurred:"); 
                        for (var x:Object in status) { 
                            LogUtil.error(x + " : " + status[x]); 
                        } 
                    }
                ) //new Responder
            ); //_netConnection.call
        }
        
        
        /**
         * Send an event out to the server to go to a new page in the SlidesDeck 
         * @param page
         * 
         */		
        public function gotoSlide(num:int) : void {
            red5Conn.connection.call("presentation.gotoSlide",// Remote function name
                new Responder(
                    // On successful result
                    function(result:Boolean):void { 
                        
                        if (result) {
                            LogUtil.debug("Successfully moved page to: " + num);							
                        }	
                    },	
                    // status - On error occurred
                    function(status:Object):void { 
                        LogUtil.error("Error occurred:"); 
                        for (var x:Object in status) { 
                            LogUtil.error(x + " : " + status[x]); 
                        } 
                    }
                ), //new Responder
                num
            ); //_netConnection.call
        }
        
        /**
         * A callback method. It is called after the gotoPage method has successfully executed on the server
         * The method sets the clients view to the page number received 
         * @param page
         * 
         */		
        public function gotoSlideCallback(page:Number) : void {
            var e:NavigationEvent = new NavigationEvent(NavigationEvent.GOTO_PAGE)
            e.pageNumber = page;
            _dispatcher.dispatchEvent(e);
        }
               
        public function sharePresentation(share:Boolean, presentationName:String):void {
            LogUtil.debug("PresentationSOService::sharePresentation()... presentationName=" + presentationName);
            red5Conn.connection.call("presentation.sharePresentation",// Remote function name
                new Responder(
                    // On successful result
                    function(result:Boolean):void { 
                        
                        if (result) {
                            LogUtil.debug("Successfully shared presentation");							
                        }	
                    },	
                    // status - On error occurred
                    function(status:Object):void { 
                        LogUtil.error("Error occurred:"); 
                        for (var x:Object in status) { 
                            LogUtil.error(x + " : " + status[x]); 
                        } 
                    }
                ), //new Responder
                presentationName,
                share
            ); //_netConnection.call
        }
        
        public function sharePresentationCallback(presentationName:String, share:Boolean):void {
            LogUtil.debug("sharePresentationCallback " + presentationName + "," + share);
            if (share) {
                var e:UploadEvent = new UploadEvent(UploadEvent.PRESENTATION_READY);
                e.presentationName = presentationName;
                _dispatcher.dispatchEvent(e);
            } else {
                _dispatcher.dispatchEvent(new UploadEvent(UploadEvent.CLEAR_PRESENTATION));
            }
        }
        
        public function removePresentationCallback(presentationName:String):void {
            LogUtil.debug("removePresentationCallback " + presentationName);
            var e:RemovePresentationEvent = new RemovePresentationEvent(RemovePresentationEvent.PRESENTATION_REMOVED_EVENT);
            e.presentationName = presentationName;
            _dispatcher.dispatchEvent(e);
        }
        
        public function pageCountExceededUpdateMessageCallback(conference:String, room:String, 
                                                               code:String, presentationName:String, messageKey:String, numberOfPages:Number, 
                                                               maxNumberOfPages:Number) : void {
            LogUtil.debug("pageCountExceededUpdateMessageCallback:Received update message " + messageKey);
            var uploadEvent:UploadEvent = new UploadEvent(UploadEvent.PAGE_COUNT_EXCEEDED);
            uploadEvent.maximumSupportedNumberOfSlides = maxNumberOfPages;
            _dispatcher.dispatchEvent(uploadEvent);
        }
        
        public function generatedSlideUpdateMessageCallback(conference:String, room:String, 
                                                            code:String, presentationName:String, messageKey:String, numberOfPages:Number, 
                                                            pagesCompleted:Number) : void {
            LogUtil.debug( "CONVERTING = [" + pagesCompleted + " of " + numberOfPages + "]");					
            var uploadEvent:UploadEvent = new UploadEvent(UploadEvent.CONVERT_UPDATE);
            uploadEvent.totalSlides = numberOfPages;
            uploadEvent.completedSlides = pagesCompleted;
            _dispatcher.dispatchEvent(uploadEvent);	
        }
        
        public function conversionCompletedUpdateMessageCallback(conference:String, room:String, 
                                                                 code:String, presentationName:String, messageKey:String, slidesInfo:String) : void {
            LogUtil.debug("conversionCompletedUpdateMessageCallback:Received update message " + messageKey);
            presentationModel.addPresentation(presentationName);
            presentationModel.setCurrentPresentation(presentationName);
            
            var uploadEvent:UploadEvent = new UploadEvent(UploadEvent.CONVERT_SUCCESS);
            uploadEvent.data = messageKey;
            uploadEvent.presentationName = presentationName;
            _dispatcher.dispatchEvent(uploadEvent);

        }
        
        public function conversionUpdateMessageCallback(conference:String, room:String, 
                                                        code:String, presentationName:String, messageKey:String) : void {
            LogUtil.debug("conversionUpdateMessageCallback:Received update message " + messageKey);
            var totalSlides : Number;
            var completedSlides : Number;
            var message : String;
            var uploadEvent:UploadEvent;
            
            switch (messageKey) {
                case "OFFICE_DOC_CONVERSION_SUCCESS":
                    uploadEvent = new UploadEvent(UploadEvent.OFFICE_DOC_CONVERSION_SUCCESS);
                    _dispatcher.dispatchEvent(uploadEvent);
                    break;
                case "OFFICE_DOC_CONVERSION_FAILED":
                    uploadEvent = new UploadEvent(UploadEvent.OFFICE_DOC_CONVERSION_FAILED);
                    _dispatcher.dispatchEvent(uploadEvent);
                    break;
                case "SUPPORTED_DOCUMENT":
                    uploadEvent = new UploadEvent(UploadEvent.SUPPORTED_DOCUMENT);
                    _dispatcher.dispatchEvent(uploadEvent);
                    break;
                case "UNSUPPORTED_DOCUMENT":
                    uploadEvent = new UploadEvent(UploadEvent.UNSUPPORTED_DOCUMENT);
                    _dispatcher.dispatchEvent(uploadEvent);
                    break;
                case "GENERATING_THUMBNAIL":	
                    _dispatcher.dispatchEvent(new UploadEvent(UploadEvent.THUMBNAILS_UPDATE));
                    break;		
                case "PAGE_COUNT_FAILED":
                    uploadEvent = new UploadEvent(UploadEvent.PAGE_COUNT_FAILED);
                    _dispatcher.dispatchEvent(uploadEvent);
                    break;	
                case "GENERATED_THUMBNAIL":
                    LogUtil.warn("conversionUpdateMessageCallback:GENERATED_THUMBNAIL_KEY " + messageKey);
                    break;
                default:
                    LogUtil.warn("conversionUpdateMessageCallback:Unknown message " + messageKey);
                    break;
            }														
        }	
                
        private function notifyConnectionStatusListener(connected:Boolean, errors:Array=null):void {
            if (_connectionListener != null) {
                _connectionListener(connected, errors);
            }
        }
        
        private function syncHandler(event:SyncEvent):void {
            notifyConnectionStatusListener(true);		
            getPresentationInfo();	
        }
        
        private function netStatusHandler (event:NetStatusEvent):void {
            var statusCode:String = event.info.code;
            LogUtil.debug("!!!!! Presentation status handler - " + event.info.code );
            switch (statusCode) {
                case "NetConnection.Connect.Success":
                    LogUtil.debug(":Connection Success");
                    notifyConnectionStatusListener(true);		
                    getPresentationInfo();	
                    break;			
                case "NetConnection.Connect.Failed":
                    addError("PresentSO connection failed");			
                    break;					
                case "NetConnection.Connect.Closed":
                    addError("Connection to PresentSO was closed.");									
                    notifyConnectionStatusListener(false, _soErrors);
                    break;					
                case "NetConnection.Connect.InvalidApp":
                    addError("PresentSO not found in server");				
                    break;					
                case "NetConnection.Connect.AppShutDown":
                    addError("PresentSO is shutting down");
                    break;					
                case "NetConnection.Connect.Rejected":
                    addError("No permissions to connect to the PresentSO");
                    break;					
                default :
                    LogUtil.debug(":default - " + event.info.code );
                    break;
            }
        }
        
        private function asyncErrorHandler (event:AsyncErrorEvent):void {
            addError("PresentSO asynchronous error.");
        }
        
        private function addError(error:String):void {
            if (_soErrors == null) {
                _soErrors = new Array();
            }
            _soErrors.push(error);
        }
    }
}