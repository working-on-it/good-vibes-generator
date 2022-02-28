import { ActivityHandler, CardFactory, MessageFactory, TurnContext } from "botbuilder";
import * as ACData from "adaptivecards-templating";
import { CosmosDB } from "./CosmosDb";
import { Conversation } from "../types/Conversation";
import { GoodVibeGenerator } from "./GoodVibeGenerator";
import * as GoodVibeCard from "../cards/GoodVibeCard.json";
import * as WelcomeCard from "../cards/WelcomeCard.json";

export class GoodVibesBot extends ActivityHandler {
    constructor() {
        super();

        this.onMessage(async (context, next) => {

            // Store conversation reference for sending out good vibes
            const conversationReference = TurnContext.getConversationReference(context.activity);
            const conversation: Conversation = {
                id: context.activity.from.aadObjectId,
                displayName: context.activity.from.name,
                conversationReference
            }
            const cosmos = CosmosDB.getInstance();
            await cosmos.upsertConversation(conversation);

            const goodVibeGenerator = GoodVibeGenerator.getInstance();
            const goodVibe = await goodVibeGenerator.getVibe();

            // Create data for card
            const cardData = {
                goodVibe
            }

            const template = new ACData.Template(GoodVibeCard);
            const cardPayload = template.expand({ $root: cardData });
            const card = CardFactory.adaptiveCard(cardPayload);

            await context.sendActivity(MessageFactory.attachment(card));
            await next();
        });

        this.onMembersAdded(async (context, next) => {
            const membersAdded = context.activity.membersAdded;
            const card = CardFactory.adaptiveCard(WelcomeCard);
            for (const member of membersAdded) {
                if (member.id !== context.activity.recipient.id) {
                    await context.sendActivity(MessageFactory.attachment(card));
                }
            }
            await next();
        });
    }
}