import * as df from "durable-functions"
import { Task } from "durable-functions/lib/src/classes";
import { GoodVibeGenerator } from "../modules/GoodVibeGenerator";
import { Conversation } from "../types/Conversation";

const orchestrator = df.orchestrator(function* (context) {

    const firstRetryIntervalInMilliseconds = 5000;
    const maxNumberOfAttempts = 5;
    const retryOptions = new df.RetryOptions(firstRetryIntervalInMilliseconds, maxNumberOfAttempts);

    let notifications: Task[] = [];
    let outputs: unknown;

    // Get all conversations
    const conversations: Conversation[] = yield context.df.callActivityWithRetry("getConversations", retryOptions);

    if (conversations.length > 0) {
        // Send notification for each booking
        for (const conversation of conversations) {
            const goodVibe = yield context.df.callActivityWithRetry("getGoodVibe", retryOptions);
            const notification = context.df.callActivityWithRetry("sendGoodVibeToConversation", retryOptions, { conversation, goodVibe });
            notifications.push(notification);
        }

        if (notifications.length > 0) {
            outputs = yield context.df.Task.all(notifications);
        }
    }

    context.log(outputs);
    return outputs;
});

export default orchestrator;
