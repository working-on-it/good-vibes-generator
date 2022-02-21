import { AzureFunction, Context } from "@azure/functions"
import { CardFactory, MessageFactory, TurnContext } from "botbuilder";
import * as ACData from "adaptivecards-templating";
import { BotAdapterInstance } from "../modules/BotAdapter";
import { Conversation } from "../types/Conversation";
import * as GoodVibeCard from "../cards/GoodVibeCard.json";

const activityFunction: AzureFunction = async function (context: Context): Promise<any> {
    context.log(`Sending notification`);
    try {
        const conversation: Conversation = context.bindingData.conversation;
        // Verify it is a valid conversation reference
        if (context.bindingData.goodVibe &&
            conversation.conversationReference &&
            conversation.conversationReference.conversation &&
            conversation.conversationReference.conversation.tenantId === process.env.MicrosoftAppTenantId) {

            // Create data for card
            const cardData = {
                goodVibe: context.bindingData.goodVibe
            }

            const template = new ACData.Template(GoodVibeCard);
            const cardPayload = template.expand({ $root: cardData });
            const card = CardFactory.adaptiveCard(cardPayload);
            const activity = MessageFactory.attachment(card);

            const botAdapterInstance = BotAdapterInstance.getInstance();
            await botAdapterInstance.adapter.continueConversationAsync(process.env.MicrosoftAppId, conversation.conversationReference, async (turnContext: TurnContext) => {
                const sentCard = await turnContext.sendActivity(activity);
                context.done(null, sentCard);
            });
        }
    } catch (error) {
        throw error;
    }
};

export default activityFunction;
