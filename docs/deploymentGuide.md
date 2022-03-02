# Deployment guide

This guide shall walk you though the steps that you need to do in order to deploy the our Good Vibes Generator into your tenant.

## Overview

It's a good idea to first familiarize yourself with the resources:

![Good Vibes Generator overview](media/overview.drawio.png)

* We chose cosmos DB to store the data, because //TODO
* At the very heart of the solution, you will find the good-vibes function app, which is the brain of the Good Vibes Generator. It contains 7 different functions which orchestrate the conversation with the bot and send messages to the user as Adaptive Cards.

* We use [Azure Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview) to handle authentication which means that no app registration in Azure Active Directory is necessary.

* Users interact with the bot in a chat in Microsoft Teams

## Deploying

1. Fork the [good vibes generator repository](https://github.com/working-on-it/good-vibes-generator)
2. Open [Azure cloud shell](https://shell.azure.com)
3. Clone your fork with `git clone https://github.com/<your account here>/good-vibes-generator`
4. Run `wget https://github.com/working-on-it/good-vibes-generator/releases/latest/download/good-vibes-generator.zip && unzip good-vibes-generator -d good-vibes-generator && cd good-vibes-generator/deployment`
5. Run `.\deploy.ps1`
6. The script will prompt you to provide 
   * a location - this is the Azure region that you want to use. If you need to get an overview about the available regions, type `az account list-locations -o table`
   * your Azure subscription (you can either obtain this from the [Azure portal](https://portal.azure.com/#blade/Microsoft_Azure_Billing/SubscriptionsBlade) or with `az account show --output table`)
The script will now deploy all resource in your tenant. You can check in the Azure portal after you see the **Deployment completed** message.

To add Good Vibes to Teams,

* Go to your **Good Vibes** resource group
* Select the **good-vibes-bot**
* Select **Channels**
* Select the **Open in Teams** link.
