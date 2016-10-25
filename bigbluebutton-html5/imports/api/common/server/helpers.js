import { clearUsersCollection } from '/imports/api/users/server/modifiers/clearUsersCollection';
import clearChats from '/imports/api/chat/server/modifiers/clearChats';
import { clearShapesCollection } from '/imports/api/shapes/server/modifiers/clearShapesCollection';
import { clearSlidesCollection } from '/imports/api/slides/server/modifiers/clearSlidesCollection';
import { clearPresentationsCollection }
  from '/imports/api/presentations/server/modifiers/clearPresentationsCollection';
import { clearMeetingsCollection }
  from '/imports/api/meetings/server/modifiers/clearMeetingsCollection';
import { clearPollCollection } from '/imports/api/polls/server/modifiers/clearPollCollection';
import { clearCursorCollection } from '/imports/api/cursor/server/modifiers/clearCursorCollection';
import { clearCaptionsCollection }
  from '/imports/api/captions/server/modifiers/clearCaptionsCollection';
import { logger } from '/imports/startup/server/logger';
import { redisPubSub } from '/imports/startup/server';
import { BREAK_LINE, CARRIAGE_RETURN, NEW_LINE } from '/imports/utils/lineEndings.js';

export function appendMessageHeader(eventName, messageObj) {
  let header;
  header = {
    timestamp: new Date().getTime(),
    name: eventName,
  };
  messageObj.header = header;
  return messageObj;
};

export function clearCollections() {
  console.log('in function clearCollections');

  /*
    This is to prevent collection clearing in development environment when the server
    refreshes. Related to: https://github.com/meteor/meteor/issues/6576
  */

  if (process.env.NODE_ENV === 'development') {
    return;
  }

  const meetingId = arguments[0];
  if (meetingId != null) {
    clearUsersCollection(meetingId);
    clearChats(meetingId);
    clearMeetingsCollection(meetingId);
    clearShapesCollection(meetingId);
    clearSlidesCollection(meetingId);
    clearPresentationsCollection(meetingId);
    clearPollCollection(meetingId);
    clearCursorCollection(meetingId);
    clearCaptionsCollection(meetingId);
  } else {
    clearUsersCollection();
    clearChats();
    clearMeetingsCollection();
    clearShapesCollection();
    clearSlidesCollection();
    clearPresentationsCollection();
    clearPollCollection();
    clearCursorCollection();
    clearCaptionsCollection();
  }
}

export const indexOf = [].indexOf || function (item) {
    for (let i = 0, l = this.length; i < l; i++) {
      if (i in this && this[i] === item) {
        return i;
      }
    }

    return -1;
  };

export function publish(channel, message) {
  return redisPubSub.publish(channel, message.header.name, message.payload, message.header);
};

// translate '\n' newline character and '\r' carriage
// returns to '<br/>' breakline character for Flash
export const translateHTML5ToFlash = function (message) {
  let result = message;
  result = result.replace(new RegExp(CARRIAGE_RETURN, 'g'), BREAK_LINE);
  result = result.replace(new RegExp(NEW_LINE, 'g'), BREAK_LINE);
  return result;
};

// when requesting for history information we pass this made up requesterID
// We want to handle only the reports we requested
export const inReplyToHTML5Client = function (arg) {
  return arg.payload.requester_id === 'nodeJSapp';
};
