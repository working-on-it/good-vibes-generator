# How to build a Good Vibes generator for Microsoft Teams

![overview](media/overview.drawio.png)

## Idea

### A Microsoft Teams bot

We want Good Vibes. The world is a tough place to be and we all can use some positive affirmations and a little pep talk. Wouldn't it be awesome if these get straight into Microsoft Teams?

![good vibes chat](media/ExampleTeamsConversation.png)

So what we need is a nice pile of messages to send, but that would get pretty boring very soon if there is not a lot of variety. So we decided to split our messages into four pieces:

> The general construct of a Good Vibe is made up of 4 phrases put together. This roughly equates to:
>
> * Phrase 1 - Greeting e.g. "Hey!" or "Listen Up:"
> * Phrase 2 - Address a personal trait or object e.g. "your hair" or "your personality"
> * Phrase 3 - Compliment e.g. "is awesome,", "absolutely rules the world,". Typically this phrase ends with a comma to help the vibe flow better
> * Phrase 4 - End the vibe e.g. "and that's a fact." or "for reals."

and then create a Good Vibe by randomly stitching these parts together. This means, that we can have a way more unique messages and no two people see the same message at the same time.

### Key design goals

Before we started, we had some clear design goals to keep in mind:

* Secret-less - Where possible, do not use secrets. Secrets are a pain to manage (expiry, rotation) and something you need to keep safe
* Server-less - We wanted to build an application that scales (cost wise) with usage. If you don't use it often, it doesn't cost you much
* Open source - We believe in open source solutions and wanted to provide something that can be updated, improved and loved by the community

## Let's build it in Azure

### Managed Identities

We love Azure Managed Identities ❤. They are the state-of-the-art way to handle authentication for Azure resources. Managed Identities give your app an identity, which means that you don't need to register an application in Azure Active Directory (or other authentication methods) and then have hassle with managing/rotating secrets or signing certificates. Managed Identities come in two flavours:

* System-assigned Managed Identity, which is tied to the lifecycle of another Azure resource and can't be used for any other resource
* User-assigned Managed Identity, which is an Azure resource just on its own and can be used with several other resources

In our solution, we unfortunately need both, as there is some inconsistencies with which resources support which Managed Identity type.

### Key Vault

Although our aim is to be secret-less with Managed Identities for authentication, we still need to hold some information that we would prefer not stored in plain text. For example, the tenant ID. This is where Key Vault comes in to store these. However, we are also using a Managed Identity to access Key Vault, which satisfies our goal of being secret-less.

### Cosmos DB

Using Cosmos DB to store all phrases so that they can be picked up by the Azure Function was a logical choice, as Cosmos is cheap, serverless, schema-less and easy to use.

### Azure Functions

Azure Functions are used to run the application logic. This comprises of two main tasks:

* Respond to someone messaging the bot with a Good Vibe
* Automatically send out Good Vibes on a schedule

### Storage Account

A Storage Account is required to allow the (durable) Azure Functions to run correctly. In addition, the app package that the Azure Functions runs from is stored in the Storage Account.

### Bot

A Bot handles the connection between Teams and Azure Functions. When a user messages the Bot, it forwards this on to our Azure functions.

### Adaptive Cards

We created two Adaptive Cards:

* **WelcomeCard**, which is sent on first run to greet the user and introduce what the Good Vibes generator is about
* **GoodVibeCard**, which contains a Good Vibe

which are both sent via the `sendGoodVibesToConversation` Azure function.

Adaptive Cards make it super easy to have a nice looking message in Teams while we don't need to worry about the UI at all. They just render beautifully and fully adapt the look and feel of Teams, theme included.

## Make it deployable

As we believe, that really everyone deserves Good Vibes, this is an open-source project - which you can deploy into your tenant. If interested, head over to our [Deployment Guide](https://github.com/working-on-it/good-vibes-generator/docs/deploymentGuide.md). We provide you with instructions and all files you need. It's super easy to get started!

### ARM template, but as 💪

We don't want you to give you a lengthy README file which guides you to click your way through the Azure portal to rebuild what we built, which is why we created deployment files for you. And as we wanted to use what the kool kids do, we used .bicep 💪 as our language to describe the infrastructure that needs to be created.

### Zip file

Once the deployment in Azure has completed, the other step is to upload the app package in to Azure Functions. The app package is a pre-built package with the code transpiled and all dependencies installed. This helps speed up cold start times in Azure Functions.

### Deployment script

The included PowerShell script will prompt you to provide your preferred Azure region, your subscription ID and a resource prefix name. It will then deploy the bicep file and app package into your tenant. We've written the script with it being run from Azure Cloud Shell, so no modules on your local machine are required.

## Conclusion

So, there you have it. A Teams app for your users in your organisation to receive positive (and sometimes funny) messages. We can't wait to see what Good Vibes you get sent!

## Resources

* [Good Vibes generator](https://github.com/working-on-it/good-vibes-generator)
* [Welcome to Azure Cosmos DB](https://docs.microsoft.com/azure/cosmos-db/introduction)
* [Adaptive Cards](https://adaptivecards.io)
* [What are managed identities for Azure resources?](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
* [What is Bicep?](https://docs.microsoft.com/azure/azure-resource-manager/bicep/overview?tabs=bicep)
* [Quick Start: Create a TypeScript function in Azure from the command line](https://docs.microsoft.com/azure/azure-functions/create-first-function-cli-typescript?tabs=azure-cli%2Cbrowser)
* [How to install the Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
