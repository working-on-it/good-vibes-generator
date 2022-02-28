import { AzureFunction, Context } from "@azure/functions"
import { CosmosDB } from "../modules/CosmosDb";

const activityFunction: AzureFunction = async function (context: Context): Promise<any> {
    context.log("Getting all conversations");
    try {
        const cosmos = CosmosDB.getInstance();
        const conversations = await cosmos.getConversationsAll();
        context.done(null, conversations);
    } catch (error) {
        throw error;
    }
};

export default activityFunction;
