import { CosmosClient, CosmosClientOptions, FeedOptions, SqlQuerySpec } from "@azure/cosmos";
import { ManagedIdentityCredential } from "@azure/identity";
import { v4 as uuidv4 } from "uuid";
import { AppConfig } from "../types/AppConfig";
import { BaseCosmosItem } from "../types/BaseCosmosItem";
import { Conversation } from "../types/Conversation";

export class CosmosDB {
    private static instance: CosmosDB;
    private database: string;
    private cosmosClient: CosmosClient;
    private retryMaxCount: number = 20;

    private containerConfig = "config";
    private containerConversations = "conversations";

    private constructor() {
        try {
            this.database = process.env.CosmosDbDatabase;
            const endpoint = process.env.CosmosDbUri;
            const key = process.env.CosmosDbKey;
            let cosmosClientOptions: CosmosClientOptions;

            // Get credentials
            if (endpoint && key) {
                // Use env vars if specified
                cosmosClientOptions = { endpoint, key };
            } else if (endpoint) {
                // Use MI
                cosmosClientOptions = { endpoint, aadCredentials: new ManagedIdentityCredential() }
            } else {
                throw new Error("Unable to create client due to missing endpoint and/or key");
            }

            this.cosmosClient = new CosmosClient(cosmosClientOptions);

        } catch (err) {
            const error = err as any;
            this.handleError(error);
        }
    }

    public static getInstance(): CosmosDB {
        if (!this.instance) {
            this.instance = new this();
        }

        return this.instance;
    }

    /** Retry handler for failed operations */
    private retryHandler(attempt: number) {
        const msToWait = attempt * 1000;
        if (attempt < this.retryMaxCount) {
            console.log(`Retrying Cosmos DB Operation (Attempt #${attempt}) in ${msToWait}ms`);
            return new Promise(resolve => setTimeout(resolve, attempt * 1000));
        } else {
            throw new Error(`Cosmos DB Operation has exceeded maximum number of retries (${this.retryMaxCount})`);
        }
    }

    private handleError(error: any) {
        // Send error to application insights
        throw new Error(`Cosmos DB operation has failed with the error: ${error}`);
    }

    /**
     * Generic method for getting an item from the specified Cosmos container
     *
     * @param id Id of the item to get from the Cosmos container
     * @param containerName Name of the Cosmos container to get the item from
     * @param partitionKey Value of the partition key field/property
     * @returns Strongly typed item
     */
    private async getItem<T extends BaseCosmosItem>(id: string, containerName: string, partitionKey?: string, attempt: number = 1): Promise<T | undefined> {
        try {
            // Get the item
            const { resource: item } = await this.cosmosClient
                .database(this.database)
                .container(containerName)
                .item(id, (partitionKey || id))
                .read<T>();

            return item as T;

        } catch (err) {
            const error = err as any;
            if (error.code === 429 || error.code === 449) {
                attempt++;
                await this.retryHandler(attempt);
                return await this.getItem<T>(id, containerName, partitionKey, attempt);
            } else {
                this.handleError(error);
            }
        }
    }

    /**
    * Generic method for getting a query result from a Cosmos container
    *
    * @param query Query definition
    * @param containerName Cosmos container name to execute the query against
    * @param feedOptions Feed options
    * @returns Either query results or a typed empty array
    */
    private async getItemsByQuery<T extends BaseCosmosItem>(query: string | SqlQuerySpec, containerName: string, feedOptions?: FeedOptions, attempt: number = 1): Promise<T[]> {
        let items: T[] = [];
        try {
            // Get data from Cosmos container
            const result = await this.cosmosClient
                .database(this.database)
                .container(containerName)
                .items
                .query(query, feedOptions)
                .fetchAll();

            if (result.resources && result.resources.length > 0) {
                items = result.resources;
            }
        } catch (err) {
            const error = err as any;
            if (error.code === 429 || error.code === 449) {
                attempt++;
                await this.retryHandler(attempt);
                return await this.getItemsByQuery<T>(query, containerName, feedOptions, attempt);
            } else {
                this.handleError(error);
            }
        }
        return items;
    }

    /**
     * Generic method for upserting item into a Cosmos container
     *
     * @param itemToUpsert Item to be upserted (updated/created) in the specified Cosmos container
     * @param containerName Name of the Cosmos container to upsert item into
     * @param attempt Attempt number of this operation
     * @returns Strongly typed upserted item
     */
    private async upsertItem<T extends BaseCosmosItem>(itemToUpsert: T, containerName: string, attempt: number = 1): Promise<T | undefined> {
        if (!itemToUpsert.id) {
            itemToUpsert.id = uuidv4();
        }

        try {
            const { resource: upsertedItem } = await this.cosmosClient
                .database(this.database)
                .container(containerName)
                .items
                .upsert(itemToUpsert);
            const itemToReturn: T = (upsertedItem as unknown) as T;

            return itemToReturn;

        } catch (err) {
            const error = err as any;
            if (error.code === 429 || error.code === 449) {
                attempt++;
                await this.retryHandler(attempt);
                return await this.upsertItem<T>(itemToUpsert, containerName, attempt);
            } else {
                this.handleError(error);
            }
        }
    }

    // Returns the config if it exists, if not creates it and returns a new config
    async getConfig(): Promise<AppConfig> {
        const item = await this.getItem<AppConfig>("0", this.containerConfig);

        if (item) {
            return item;
        } else {
            // Pre-create app configuration from the default configuration
            const defaultConfiguration: AppConfig = {
                id: "0",
                firstPhrases: [
                    "Hey,",
                    "Fact:",
                    "Everybody says",
                    "Dang...",
                    "Check it:",
                    "Just saying...",
                    "Superstar,",
                    "Tiger,",
                    "Self",
                    "Know this:",
                    "News alert:",
                    "You know,",
                    "Ace,",
                    "Excuse me but,",
                    "Experts agree:",
                    "In my opinion,",
                    "Hear ye, hear ye:",
                    "Okay, listen up:"
                ],
                secondPhrases: [
                    "the mere idea of you",
                    "your soul",
                    "your hair today",
                    "everything you do",
                    "your personal style",
                    "every thought you have",
                    "that sparkle in your eye",
                    "your presence here",
                    "what you got going on",
                    "the essential you",
                    "your life's journey",
                    "that saucy personality",
                    "your DNA",
                    "that brain of yours",
                    "your choice of attire",
                    "the way you roll",
                    "whatever your secret is",
                    "all of y'all"
                ],
                thirdPhrases: [
                    "has serious game,",
                    "rains magic,",
                    "deserves a Nobel Prize,",
                    "raises the roof,",
                    "breeds miracles,",
                    "is paying off big time,",
                    "shows mad skills,",
                    "just shimmers,",
                    "is a national treasure,",
                    "gets the party hopping,",
                    "is the next big thing,",
                    "is the next big thing,",
                    "roars like a lion,",
                    "is a rainbow factory,",
                    "is made of diamonds,",
                    "makes birds sing,",
                    "should be taught in school,",
                    "makes my world go 'round',",
                    "is 100% legit,",
                    "is 🔥,"
                ],
                fourthPhrases: [
                    "24/7.",
                    "can I get an amen?",
                    "and that's a fact.",
                    "so treat yourself.",
                    "you feel me?",
                    "that's just science.",
                    "would I lie?",
                    "for reals.",
                    "mic drop.",
                    "you hidden gem.",
                    "snuggle bear.",
                    "period.",
                    "I mean it.",
                    "now let's dance.",
                    "high five.",
                    "say it again!",
                    "according to the news.",
                    "so get used to it."
                ]
            }
            await this.upsertConfig(defaultConfiguration);
            return defaultConfiguration;
        }
    }

    // Create/Update a configuration
    async upsertConfig(config: AppConfig): Promise<AppConfig | undefined> {
        return await this.upsertItem<AppConfig>(config, this.containerConfig);
    }

    // Create/Update a conversation
    async upsertConversation(conversation: Conversation): Promise<Conversation | undefined> {
        return await this.upsertItem<Conversation>(conversation, this.containerConversations);
    }

    // Get all conversations
    async getConversationsAll(): Promise<Conversation[]> {
        const querySpec: SqlQuerySpec = {
            query: "SELECT * FROM c"
        };
        return await this.getItemsByQuery<Conversation>(querySpec, this.containerConversations);
    }

}