import React, { useEffect } from "react";
import { useSubscription } from "@apollo/client";
import { Meteor } from 'meteor/meteor';
import {
  CHAT_MESSAGE_PUBLIC_SUBSCRIPTION,
  CHAT_MESSAGE_PRIVATE_SUBSCRIPTION,
  ChatMessagePrivateSubscriptionResponse,
  ChatMessagePublicSubscriptionResponse,
} from "./queries";
import { Message } from '/imports/ui/Types/message';
import ChatMessage from './chat-message/componet';

const CHAT_CONFIG = Meteor.settings.public.chat;
const PUBLIC_GROUP_CHAT_KEY = CHAT_CONFIG.public_group_id;

interface ChatListPageContainerProps {
  page: number;
  pageSize: number;
  setLastSender: Function;
  lastSenderPreviousPage: string | undefined;
  chatId: string;
  markMessageAsSeen: Function;
}

interface ChatListPageProps {
  messages: Array<Message>;
  lastSenderPreviousPage: string | undefined;
  page: number;
  markMessageAsSeen: Function;
}

const verifyIfIsPublicChat = (message: unknown): message is ChatMessagePublicSubscriptionResponse => {
  return (message as ChatMessagePublicSubscriptionResponse).chat_message_public !== undefined;
}

const verifyIfIsPrivateChat = (message: unknown): message is ChatMessagePrivateSubscriptionResponse => {
  return (message as ChatMessagePrivateSubscriptionResponse).chat_message_private !== undefined;
}

function isInViewport(el: HTMLDivElement) {
  const rect = el.getBoundingClientRect();

  return (
    rect.top <= (window.innerHeight || document.documentElement.clientHeight) &&
    rect.bottom >= 0
  );
}
const markOnScrollEnd = (messages: Array<Message>, page: number, markMessageAsSeen: Function) => {
  markMessageAsSeen(messages[messages.length - 1], page);
}
const ChatListPage: React.FC<ChatListPageProps> = ({ messages, lastSenderPreviousPage, page, markMessageAsSeen }) => {
  const pageRef = React.useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (pageRef.current) {
      if (isInViewport(pageRef.current)) {
        markMessageAsSeen(messages[messages.length - 1], page);
      } else {
        // first parent is the resize observer, the second is the scroll container
        const scrollContainer = pageRef.current?.parentNode?.parentNode;
        if (scrollContainer) {
          scrollContainer.addEventListener('scrollend', markOnScrollEnd.bind(null, messages, page, markMessageAsSeen));
        }
      }

    }
  }, [pageRef, messages.length]);
  return (
    <div key={`messagePage-${page}`} id={`${page}`} ref={pageRef}>
      {
        messages.map((message, index, Array) => {
          const previousMessage = Array[index - 1];
          return (
            <ChatMessage
              key={message.createdTime}
              message={message}
              previousMessage={previousMessage}
              lastSenderPreviousPage={!previousMessage ? lastSenderPreviousPage : null}
            />
          )
        })
      }
    </div>
  );
}

const ChatListPageContainer: React.FC<ChatListPageContainerProps> = ({
  page,
  pageSize,
  setLastSender,
  lastSenderPreviousPage,
  chatId,
  markMessageAsSeen,
}) => {
  const isPublicChat = chatId === PUBLIC_GROUP_CHAT_KEY;
  const chatQuery = isPublicChat
    ? CHAT_MESSAGE_PUBLIC_SUBSCRIPTION
    : CHAT_MESSAGE_PRIVATE_SUBSCRIPTION;
  const defaultVariables = { offset: (page) * pageSize, limit: pageSize };
  const variables = isPublicChat ? defaultVariables : { ...defaultVariables, requestedChatId: chatId };
  const {
    data: chatMessageData,
    loading: chatMessageLoading,
    error: chatMessageError,
  } = useSubscription<ChatMessagePublicSubscriptionResponse | ChatMessagePrivateSubscriptionResponse>(
    chatQuery,
    { variables }
  );

  if (chatMessageError) return (<p>chatMessageError: {JSON.stringify(chatMessageError)}</p>);
  if (chatMessageLoading) return null;
  let messages: Array<Message> = [];
  if (verifyIfIsPublicChat(chatMessageData)) {
    messages = chatMessageData.chat_message_public || [];
  } else if (verifyIfIsPrivateChat(chatMessageData)) {
    messages = chatMessageData.chat_message_private || [];
  }

  if (messages.length > 0) {
    setLastSender(page, messages[messages.length - 1].user?.userId);

  }

  return (
    <ChatListPage
      messages={messages}
      lastSenderPreviousPage={lastSenderPreviousPage}
      page={page}
      markMessageAsSeen={markMessageAsSeen}
    />
  );
}

export default ChatListPageContainer;
