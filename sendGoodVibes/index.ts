import * as df from "durable-functions"
import { AzureFunction, Context } from "@azure/functions"

const timerTrigger: AzureFunction = async function (context: Context, myTimer: any): Promise<any> {

    const client = df.getClient(context);
    const instanceId = await client.startNew("goodVibesOrchestrator");

    context.log(`Started orchestration with ID: '${instanceId}'`);

    return instanceId;

};

export default timerTrigger;
