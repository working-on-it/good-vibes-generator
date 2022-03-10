# Deployment guide

This guide shall walk you though the steps that you need to do in order to deploy the our Good Vibes Generator into your tenant.

## Overview

It's a good idea to first familiarize yourself with the resources:

![Good Vibes Generator overview](media/overview.drawio.png)

* We chose cosmos DB to store the data, because its fast, cheap, server-less, schema-less and works well with storing JSON documents (e.g. bot conversations)
* At the very heart of the solution, you will find the Good Vibes function app, which is the brain of the Good Vibes generator. It contains 7 different functions which orchestrate the conversation with the bot and send messages to the user as Adaptive Cards
* We use [Azure Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview) to handle authentication which means that no app registration in Azure Active Directory is necessary
* Users interact with the bot in a chat in Microsoft Teams

## Deploying

1. Open [Azure cloud shell](https://shell.azure.com). If prompted, choose "PowerShell" shell type.
2. Run `wget -O good-vibes-generator.zip https://github.com/working-on-it/good-vibes-generator/releases/latest/download/good-vibes-generator.zip && unzip good-vibes-generator -d good-vibes-generator && cd good-vibes-generator/deployment`
3. Run `./deploy.ps1`
4. The script will prompt you to provide
   * `Location` - this is the Azure region that you want to use. If you need to get an overview about the available regions, type `az account list-locations -o table`
   * `SubscriptionId` - Your Azure subscription ID (you can either obtain this from the [Azure portal](https://portal.azure.com/#blade/Microsoft_Azure_Billing/SubscriptionsBlade) or with `az account show --output table`)
   * `AzureResourcePrefix` - The prefix that will be used in-front of your azure resources e.g. "gvg123"
   * (Optional) `ResourceGroupName` - The name of the resource group that will be used/created within the subscription. If not specified, **GoodVibesGenerator** will be used

The script will now deploy all resources in your tenant. You can check in the Azure portal after you see the **Deployment completed** message.

To add Good Vibes to Teams:

1. Go to the [Azure portal](https://portal.azure.com)
2. Locate the resource group that was created during deployment
3. Find the **Azure bot** (ends in -bot) that was created inside the resource group and under **Configuration** copy the **Microsoft App ID**
   ![example bot id](media/BotID.png)
4. Download the [latest release](https://github.com/working-on-it/good-vibes-generator/releases/latest/download/good-vibes-generator.zip) on your machine
5. Extract the `good-vibes-generator.zip` file
6. Open the extracted folder and go to the `teamsAppPackage` folder
7. Open `manifest.json` and change **botId** from `<<botIdHere>>` to the **Microsoft App ID** from the Azure portal
8. Zip up the 3 files inside of the `teamsAppPackage` folder
9. Go to the [Teams admin center](https://admin.teams.microsoft.com)
10. Under **Manage Apps**, select **Upload** and choose the zip file you created
   ![teams manage app](media/TeamsAdmin1.png)
11. The **Good Vibes** app should now be available in the list
   ![good vibes app teams admin](media/TeamsAdmin2.png)

## Configuration

### Change good vibes

If you want to change some phrases, remove some or add new one, this can be done in the `config` container in Cosmos in Item **0**.  You will find 4 arrays that hold all phrases that make the good vibes. Feel free to share your additions with us 💖.

> The general construct of a Good Vibe is made up of 4 phrases put together. This roughly equates to:
>
> * Phrase 1 - Greeting e.g. "Hey!" or "Listen Up:"
> * Phrase 2 - Address a personal trait or object e.g. "your hair" or "your personality"
> * Phrase 3 - Compliment e.g. "is awesome,", "absolutely rules the world,". Typically this phrase ends with a comma to help the vibe flow better
> * Phrase 4 - End the vibe e.g. "and that's a fact." or "for reals."

![Cosmos DB container](media/CosmosDB-container.png)

### Set a schedule

The default behaviour is that Good Vibes are sent once a day at 12PM (UTC). If you wish to change this schedule, it can be changed by modifying the `GoodVibesSchedule` Application Setting of the Function App Configuration. This is an [NCRONTAB expression](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-timer?tabs=csharp#ncrontab-expressions) so it needs to follow that format. For example, to run at 9.30AM (UTC) Monday-Friday, you would set it to **0 30 9 * * 1-5**.

![GoodVibesSchedule](media/GoodVibesSchedule.png)
