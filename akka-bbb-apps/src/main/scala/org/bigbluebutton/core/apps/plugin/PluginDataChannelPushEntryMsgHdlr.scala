package org.bigbluebutton.core.apps.plugin

import org.bigbluebutton.common2.msgs.PluginDataChannelPushEntryMsg
import org.bigbluebutton.ClientSettings
import org.bigbluebutton.core.db.PluginDataChannelEntryDAO
import org.bigbluebutton.core.domain.MeetingState2x
import org.bigbluebutton.core.models.{ Roles, Users2x }
import org.bigbluebutton.core.running.{ HandlerHelpers, LiveMeeting }

trait PluginDataChannelPushEntryMsgHdlr extends HandlerHelpers {

  def handle(msg: PluginDataChannelPushEntryMsg, state: MeetingState2x, liveMeeting: LiveMeeting): Unit = {
    val pluginsDisabled: Boolean = liveMeeting.props.meetingProp.disabledFeatures.contains("plugins")
    val meetingId = liveMeeting.props.meetingProp.intId

    for {
      _ <- if (!pluginsDisabled) Some(()) else None
      user <- Users2x.findWithIntId(liveMeeting.users2x, msg.header.userId)
    } yield {
      val pluginsConfig = ClientSettings.getPluginsFromConfig(ClientSettings.clientSettingsFromFile)

      if (!pluginsConfig.contains(msg.body.pluginName)) {
        println(s"Plugin '${msg.body.pluginName}' not found.")
      } else if (!pluginsConfig(msg.body.pluginName).dataChannels.contains(msg.body.channelName)) {
        println(s"Data channel '${msg.body.channelName}' not found in plugin '${msg.body.pluginName}'.")
      } else {
        val hasPermission = for {
          pushPermission <- pluginsConfig(msg.body.pluginName).dataChannels(msg.body.channelName).pushPermission
        } yield {
          pushPermission.toLowerCase match {
            case "all"       => true
            case "moderator" => user.role == Roles.MODERATOR_ROLE
            case "presenter" => user.presenter
            case _           => false
          }
        }

        if (!hasPermission.contains(true)) {
          println(s"No permission to write in plugin: '${msg.body.pluginName}', data channel: '${msg.body.channelName}'.")
        } else {
          PluginDataChannelEntryDAO.insert(
            meetingId,
            msg.body.pluginName,
            msg.body.channelName,
            msg.body.subChannelName,
            msg.header.userId,
            msg.body.payloadJson,
            msg.body.toRoles,
            msg.body.toUserIds
          )
        }
      }
    }
  }
}
