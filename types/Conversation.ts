import { ConversationReference } from "botbuilder";
import { BaseCosmosItem } from "./BaseCosmosItem";

export interface Conversation extends BaseCosmosItem {
    displayName: string;
    conversationReference: Partial<ConversationReference>;
}