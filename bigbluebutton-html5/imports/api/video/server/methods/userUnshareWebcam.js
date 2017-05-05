import { Meteor } from 'meteor/meteor';
import { isAllowedTo } from '/imports/startup/server/userPermissions';
import Logger from '/imports/startup/server/logger';
import RedisPubSub from '/imports/startup/server/redis';

export default function userUnshareWebcam(credentials, message) {
  const REDIS_CONFIG = Meteor.settings.redis;
  const CHANNEL = REDIS_CONFIG.channels.toBBBApps.users;

  const { meetingId, requesterUserId, requesterToken } = credentials;

  Logger.info(' user unsharing webcam: ' , credentials);

  check(meetingId, String);
  check(requesterUserId, String);
  check(requesterToken, String);
  //check(message, Object);

  let eventName = 'user_unshare_html5_webcam_request_message';

  let actionName = 'joinVideo';
  if (!isAllowedTo(actionName, credentials)) {
    throw new Meteor.Error('not-allowed', `You are not allowed to unshare webcam`);
  }

  let payload = {
    meeting_id: meetingId,
    userid: requesterUserId
  };

  return RedisPubSub.publish(CHANNEL, eventName, payload);
}
