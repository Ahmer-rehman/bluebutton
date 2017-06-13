package org.bigbluebutton.core.running

import akka.actor.ActorContext
import org.bigbluebutton.common2.domain.{ DefaultProps, Meeting2x }
import org.bigbluebutton.core.apps._
import org.bigbluebutton.core.bus._
import org.bigbluebutton.core.models._
import org.bigbluebutton.core.OutMessageGateway
import org.bigbluebutton.core2.MeetingStatus2x

object RunningMeeting {
  def apply(props: DefaultProps, outGW: OutMessageGateway,
    eventBus: IncomingEventBus)(implicit context: ActorContext) =
    new RunningMeeting(props, outGW, eventBus)(context)
}

class RunningMeeting(val props: DefaultProps, val outGW: OutMessageGateway,
    val eventBus: IncomingEventBus)(implicit val context: ActorContext) {

  val chatModel = new ChatModel()
  val layoutModel = new LayoutModel()
  val pollModel = new PollModel()
  val wbModel = new WhiteboardModel()
  val presModel = new PresentationModel()
  val breakoutModel = new BreakoutRoomModel()
  val captionModel = new CaptionModel()
  val notesModel = new SharedNotesModel()
  val users = new Users
  val registeredUsers = new RegisteredUsers
  val meetingStatux2x = new MeetingStatus2x
  val webcams = new Webcams
  val voiceUsers = new VoiceUsers
  val voiceUsersState = new VoiceUsersState
  val users2x = new Users2x
  val usersState = new UsersState

  // meetingModel.setGuestPolicy(props.usersProp.guestPolicy)

  // We extract the meeting handlers into this class so it is
  // easy to test.
  val liveMeeting = new LiveMeeting(props, meetingStatux2x, chatModel, layoutModel,
    users, registeredUsers, pollModel, wbModel, presModel, breakoutModel, captionModel,
    notesModel, webcams, voiceUsers, voiceUsersState, users2x, usersState)

  val actorRef = context.actorOf(MeetingActor.props(props, eventBus, outGW, liveMeeting), props.meetingProp.intId)

}
