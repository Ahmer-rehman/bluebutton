/**
* BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
* 
* Copyright (c) 2012 BigBlueButton Inc. and by respective authors (see below).
*
* This program is free software; you can redistribute it and/or modify it under the
* terms of the GNU Lesser General Public License as published by the Free Software
* Foundation; either version 3.0 of the License, or (at your option) any later
* version.
* 
* BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
* WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
* PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License along
* with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.
*
*/
package org.bigbluebutton.app.video;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.red5.logging.Red5LoggerFactory;
import org.red5.server.adapter.MultiThreadedApplicationAdapter;
import org.red5.server.api.IConnection;
import org.red5.server.api.Red5;
import org.red5.server.api.scope.IScope;
import org.red5.server.api.stream.IBroadcastStream;
import org.red5.server.api.stream.IServerStream;
import org.red5.server.api.stream.IStreamListener;
import org.red5.server.stream.ClientBroadcastStream;
import org.slf4j.Logger;

public class VideoApplication extends MultiThreadedApplicationAdapter {
	private static Logger log = Red5LoggerFactory.getLogger(VideoApplication.class, "video");
	
	private IScope appScope;
	private IServerStream serverStream;
	
	private boolean recordVideoStream = false;
	private EventRecordingService recordingService;
	private final Map<String, IStreamListener> streamListeners = new HashMap<String, IStreamListener>();
	private String roomId;
	
    @Override
	public boolean appStart(IScope app) {
	    super.appStart(app);
		log.info("oflaDemo appStart");
		System.out.println("oflaDemo appStart");    	
		appScope = app;
		return true;
	}

    @Override
	public boolean appConnect(IConnection conn, Object[] params) {
		log.info("oflaDemo appConnect"); 
		return super.appConnect(conn, params);
	}

    @Override
	public void appDisconnect(IConnection conn) {
		log.info("oflaDemo appDisconnect");
		if (appScope == conn.getScope() && serverStream != null) {
			serverStream.close();
		}
		super.appDisconnect(conn);
	}
    
    @Override
    public void streamPublishStart(IBroadcastStream stream) {
    	super.streamPublishStart(stream);
    }
    
    @Override
    public void streamBroadcastStart(IBroadcastStream stream) {
    	IConnection conn = Red5.getConnectionLocal();  
    	super.streamBroadcastStart(stream);
    	log.info("streamBroadcastStart " + stream.getPublishedName() + " " + System.currentTimeMillis() + " " + conn.getScope().getName());

        if (recordVideoStream) {
	    	recordStream(stream);
	    	VideoStreamListener listener = new VideoStreamListener(roomId); 
	        listener.setEventRecordingService(recordingService);
	        stream.addStreamListener(listener); 
	        streamListeners.put(roomId + "-" + stream.getPublishedName(), listener);
        }
    }

    private Long genTimestamp() {
    	return TimeUnit.NANOSECONDS.toMillis(System.nanoTime());
    }
    
    @Override
    public void streamBroadcastClose(IBroadcastStream stream) {
    	IConnection conn = Red5.getConnectionLocal();  
    	super.streamBroadcastClose(stream);
    	
    	if (recordVideoStream) {
    		IStreamListener listener = streamListeners.remove(roomId + "-" + stream.getPublishedName());
    		if (listener != null) {
    			stream.removeStreamListener(listener);
    		}
    		
       	long publishDuration = (System.currentTimeMillis() - stream.getCreationTime()) / 1000;
        log.info("streamBroadcastClose " + stream.getPublishedName() + " " + System.currentTimeMillis() + " " + conn.getScope().getName());
    		Map<String, String> event = new HashMap<String, String>();
    		event.put("module", "WEBCAM");
    		event.put("timestamp", genTimestamp().toString());
    		event.put("meetingId", roomId);
    		event.put("stream", stream.getPublishedName());
    		event.put("duration", new Long(publishDuration).toString());
    		event.put("eventName", "StopWebcamShareEvent");	
    		recordingService.record(roomId, event);
    	}
    }
    
    /**
     * A hook to record a stream. A file is written in webapps/video/streams/
     * @param stream
     */
    private void recordStream(IBroadcastStream stream) {
    	IConnection conn = Red5.getConnectionLocal();
    	String recordingStreamName = stream.getPublishedName(); // + "-" + now; /** Comment out for now...forgot why I added this - ralam */
     
    	try {    		
    		log.info("Recording stream " + recordingStreamName );
    		ClientBroadcastStream cstream = (ClientBroadcastStream) this.getBroadcastStream(conn.getScope(), stream.getPublishedName());
    		roomId = getRoomId(recordingStreamName);
    		cstream.saveAs(roomId + "/" + recordingStreamName, false);
    	} catch(Exception e) {
    		log.error("ERROR while recording stream " + e.getMessage());
    		e.printStackTrace();
    	}    	
    }
    
	/**
	 * Get room id from the stream name
	 * 
	 * @param streamName		Stream Name
	 * @return					Parsed room id 
	 */
	private String getRoomId(String streamName) {
		// Stream name pattern is <width>x<height>-<userId>-<roomId>-<timestamp>
		Pattern streamNamePattern = Pattern.compile("\\d+x\\d+-[a-z0-9]+-([a-z0-9]+-\\d+)-\\d+");
		Matcher roomIdMatcher = streamNamePattern.matcher(streamName);
		
		if (roomIdMatcher.matches()) {
			return roomIdMatcher.group(1);
		}

		log.error("Stream name " + streamName + " has invalid format. Expected pattern is <width>x<height>-<userId>-<roomId>-<timestamp>. Unable to get room id");
		return "";
	}

	public void setRecordVideoStream(boolean recordVideoStream) {
		this.recordVideoStream = recordVideoStream;
	}
	
	public void setEventRecordingService(EventRecordingService s) {
		recordingService = s;
	}
	
}
