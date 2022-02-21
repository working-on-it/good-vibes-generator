import { AzureFunction, Context } from "@azure/functions"
import { GoodVibeGenerator } from "../modules/GoodVibeGenerator";

const activityFunction: AzureFunction = async function (context: Context): Promise<any> {
    context.log("Getting good vibe...");
    try {
        const goodVibeGenerator = GoodVibeGenerator.getInstance();
        const goodVibe = await goodVibeGenerator.getVibe();
        context.log(goodVibe);
        context.done(null, goodVibe);
    } catch (error) {
        throw error;
    }
};

export default activityFunction;
